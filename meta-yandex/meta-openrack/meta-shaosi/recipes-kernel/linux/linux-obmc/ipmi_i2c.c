/*
 * I2C IPMI driver with software slave backend
 *
 * Copyright 2016 Anton D. Kachalov <mouse@yandex-team.ru>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 */

#define pr_fmt(fmt)        "ipmi-i2c: " fmt

#include <linux/i2c.h>
#include <linux/ipmi_smi.h>
#include <linux/list.h>
#include <linux/module.h>
#include <linux/spinlock.h>
#include <linux/of.h>
#include <linux/delay.h>
#include <linux/wait.h>
#include <linux/timer.h>
#include <linux/completion.h>

#define IPMI_TIMEOUT_TIME_MSEC	1000
#define IPMI_TIMEOUT_JIFFIES	msecs_to_jiffies(IPMI_TIMEOUT_TIME_MSEC)
// (IPMI_TIMEOUT_TIME_USEC*HZ/1000000)

//#undef dev_dbg
//#define dev_dbg(x...) dev_info(x)

struct ipmb_msg {
	u8 slave;
	u8 netfn;
	u8 hdr_crc;
	u8 response;
	u8 response_lun : 2;
	u8 seq : 6;
	u8 cmd;
	union {
		struct {
			u8 cmd_crc;
			u8 data[0];
		} eq;
		u8 data[0];
	} r;
};

struct ipmi_smi_i2c {
	struct ipmi_device_id	device_id;
	ipmi_smi_t		intf;

	int (*response)(struct ipmi_smi_i2c *smi);

	/* The timer */
	struct timer_list	timer;
	struct completion	cmd_complete;

	/**
	 * We assume that there can only be one outstanding request, so
	 * keep the pending message in cur_msg. We protect this from concurrent
	 * updates through send & recv calls, (and consequently opal_msg, which
	 * is in-use when cur_msg is set) with msg_lock
	 */
	spinlock_t		msg_lock;
	int			buf_off;
	struct ipmi_smi_msg	*cur_msg;
	union {
		u8		raw[0];
		struct ipmb_msg	ipmb;
	} *msg;
	struct i2c_client	*client;
	struct i2c_client	*slave;
	u32			slave_addr;
};

static int ipmi_i2c_recv(struct ipmi_smi_i2c *smi);
static int ipmi_devid_recv(struct ipmi_smi_i2c *smi);

static u8 ipmi_crc(const u8 *buf, u32 len)
{
	u8 crc = 0;

	while (len--) {
		crc += *buf;
		buf++;
	}

	return -crc;
}

static void send_error_reply(struct ipmi_smi_i2c *smi,
		struct ipmi_smi_msg *msg, u8 completion_code)
{
	msg->rsp[0] = msg->data[0] | 0x4;
	msg->rsp[1] = msg->data[1];
	msg->rsp[2] = completion_code;
	msg->rsp_size = 3;
	ipmi_smi_msg_received(smi->intf, msg);
}

static void ipmi_i2c_timeout(unsigned long data)
{
	struct ipmi_smi_i2c *smi = (struct ipmi_smi_i2c *)data;
	struct ipmi_smi_msg *msg;
	unsigned long flags;

	spin_lock_irqsave(&smi->msg_lock, flags);
	dev_dbg(&smi->client->dev, "%s: %p\n", __func__, smi->cur_msg);
	msg = smi->cur_msg;
	if (!msg) {
		spin_unlock_irqrestore(&smi->msg_lock, flags);
		return;
	}
	msg->data[0] = smi->msg->ipmb.netfn;
	msg->data[1] = smi->msg->ipmb.cmd;
	smi->cur_msg = NULL;
	spin_unlock_irqrestore(&smi->msg_lock, flags);
	send_error_reply(smi, msg, IPMI_TIMEOUT_ERR);
}

static int ipmi_i2c_start_processing(void *send_info, ipmi_smi_t intf)
{
	struct ipmi_smi_i2c *smi = send_info;

	smi->intf = intf;
	smi->response = ipmi_i2c_recv;
	return 0;
}

static void ipmi_i2c_send(void *send_info, struct ipmi_smi_msg *msg)
{
	struct ipmi_smi_i2c *smi = send_info;
	struct ipmb_msg *ipmb_msg;
	unsigned long flags;
	int comp, rc;
	int i;
	size_t size;

	/* ensure data_len will fit in the opal_ipmi_msg buffer... */
	if (msg->data_size > IPMI_MAX_MSG_LENGTH) {
		comp = IPMI_REQ_LEN_EXCEEDED_ERR;
		goto err;
	}

	/* ... and that we at least have netfn and cmd bytes */
	if (msg->data_size < 2) {
		comp = IPMI_REQ_LEN_INVALID_ERR;
		goto err;
	}

	spin_lock_irqsave(&smi->msg_lock, flags);

	if (smi->cur_msg) {
		comp = IPMI_NODE_BUSY_ERR;
		goto err_unlock;
	}

	/* format our data for I2C block transfer */
	ipmb_msg = &smi->msg->ipmb;
	ipmb_msg->netfn = msg->data[0];
	ipmb_msg->cmd = msg->data[1];
	ipmb_msg->seq = msg->msgid;
	/* workaround for Emerson firmware (left shift) */
	ipmb_msg->slave = smi->client->addr << 1;
	ipmb_msg->response = smi->slave->addr << 1;
	ipmb_msg->hdr_crc = ipmi_crc(smi->msg->raw, 2);

	/* data_size already includes the netfn and cmd bytes and
	   smbus excludes slave address and command as first byte */
	size = sizeof(*ipmb_msg) + msg->data_size - 2 - 2;

	if (msg->data_size > 2) {
		memcpy(ipmb_msg->r.data, msg->data + 2, msg->data_size - 2);
		ipmb_msg->r.data[msg->data_size - 2] = ipmi_crc(smi->msg->raw + 3, msg->data_size + 1);
	} else {
		ipmb_msg->r.eq.cmd_crc = ipmi_crc(smi->msg->raw + 3, 3);
	}

	dev_dbg(&smi->client->dev, "%s: ipmi_send(%02x, %02x, %u %u)\n", __func__,
			ipmb_msg->netfn, ipmb_msg->cmd, msg->data_size, size);
	smi->buf_off = 0;

	for (i=0; i<size; i++) {
		dev_dbg(&smi->client->dev, "%02x ", smi->msg->raw[2+i]);
		if (i && !(i % 16))
			dev_dbg(&smi->client->dev, "\n");
	}
	dev_dbg(&smi->client->dev, "\n");

	rc = i2c_smbus_write_i2c_block_data(smi->client,
					    smi->msg->raw[1],
					    size,
					    smi->msg->raw + 2);
	dev_dbg(&smi->client->dev, "%s:  -> %d\n", __func__, rc);

	//mod_timer(&smi->timer, jiffies + IPMI_TIMEOUT_JIFFIES);
	del_timer_sync(&smi->timer);
	smi->timer.expires = jiffies + IPMI_TIMEOUT_JIFFIES;
	smi->timer.data = (long)smi;
	add_timer(&smi->timer);

	/* on timeout cur_msg will be used for error reply */
	smi->cur_msg = msg;

	if (!rc) {
		spin_unlock_irqrestore(&smi->msg_lock, flags);
		return;
	}
	smi->cur_msg = NULL;

	comp = IPMI_ERR_UNSPECIFIED;
err_unlock:
	spin_unlock_irqrestore(&smi->msg_lock, flags);
err:
	send_error_reply(smi, msg, comp);
}

static int ipmi_i2c_recv(struct ipmi_smi_i2c *smi)
{
	struct ipmb_msg *ipmb_msg;
	struct ipmi_smi_msg *msg;
	unsigned long flags;
	size_t size;
	int rc;

	dev_dbg(&smi->client->dev, "%s: ipmi_recv(msg, sz)\n", __func__);
	//del_timer_sync(&smi->timer);

	spin_lock_irqsave(&smi->msg_lock, flags);

	if (!smi->cur_msg) {
		int i;
		struct ipmi_smi_msg lmsg;
		dev_dbg(&smi->client->dev, "no current message?\n");
		smi->msg->raw[0] = smi->slave->addr << 1;
		for (i=0; i<smi->buf_off; i++) {
			dev_dbg(&smi->client->dev, "%02x ", smi->msg->raw[i]);
			if (i && !(i % 16))
				dev_dbg(&smi->client->dev, "\n");
		}
		dev_dbg(&smi->client->dev, "\n");
#if 0
		if (smi->buf_off > 5) {
			lmsg.rsp[0] = smi->msg->raw[1] >> 1;
			lmsg.rsp[1] = smi->msg->raw[5];
			if (smi->buf_off > 6) {
				memcpy(lmsg.rsp+2, smi->msg->raw+6, smi->buf_off - 5);
				lmsg.data_size = smi->buf_off - 5;
				lmsg.rsp_size = 2 + lmsg.data_size;
			} else {
				lmsg.rsp_size = 2;
				lmsg.data_size = 0;
			}
			ipmi_smi_msg_received(smi->intf, &lmsg);
		}
#endif

		spin_unlock_irqrestore(&smi->msg_lock, flags);
		return 0;
	}

	msg = smi->cur_msg;
	ipmb_msg = &smi->msg->ipmb;

	size = smi->buf_off;

	if (ipmb_msg->netfn == (smi->slave->addr << 1)) {
		size--;
		ipmb_msg = (struct ipmb_msg *)(smi->msg->raw + 1);
	}

	/* TODO: calculate & check checksum */
	rc = 0;

	dev_dbg(&smi->client->dev, "%s:   -> %d (size %u)\n", __func__,
			rc, rc == 0 ? size : 0);
	if (rc) {
		/* If came via the poll, and response was not yet ready */
#define OPAL_EMPTY 0
		if (rc == OPAL_EMPTY) {
			spin_unlock_irqrestore(&smi->msg_lock, flags);
			return 0;
		}

		smi->cur_msg = NULL;
		spin_unlock_irqrestore(&smi->msg_lock, flags);
		send_error_reply(smi, msg, IPMI_ERR_UNSPECIFIED);
		return 0;
	}

	if (size < sizeof(*ipmb_msg)) {
		int i;
		spin_unlock_irqrestore(&smi->msg_lock, flags);
		pr_warn("unexpected IPMI message size %u\n", size);
		for (i=0; i<smi->buf_off; i++) {
			printk("%02x ", smi->msg->raw[i]);
			if (i && !(i % 16))
				printk("\n");
		}
		printk("\n");
		return 0;
	}

	msg->rsp[0] = ipmb_msg->netfn;
	msg->rsp[1] = ipmb_msg->cmd;
	dev_dbg(&smi->client->dev, "netfn %02x  cmd %02x code %02x  len %02x\n", msg->rsp[0], msg->rsp[1], ipmb_msg->r.data[0], size);
	if (size > sizeof(*ipmb_msg))
		memcpy(&msg->rsp[2], ipmb_msg->r.data, size - sizeof(*ipmb_msg));
	msg->rsp_size = 2 + size - sizeof(*ipmb_msg);

	smi->cur_msg = NULL;
	spin_unlock_irqrestore(&smi->msg_lock, flags);
	ipmi_smi_msg_received(smi->intf, msg);
	return 0;
}

static int ipmi_devid_recv(struct ipmi_smi_i2c *smi)
{
	struct ipmb_msg *ipmb_msg;
	uint32_t size;
	u8 *resp;

	complete(&smi->cmd_complete);

	ipmb_msg = &smi->msg->ipmb;
	resp = smi->msg->raw;
	size = smi->buf_off;

	/* Follow the order to proper overwrite of fields */
	resp[0] = ipmb_msg->netfn;
	resp[1] = ipmb_msg->cmd;
	if (size > sizeof(*ipmb_msg))
		memmove(resp+2, ipmb_msg->r.data, size - sizeof(*ipmb_msg));

	//printk("%s: demangle sz %d   rsp %02x %02x %02x\n", __func__, size, resp[0], resp[1], resp[2]);
	return ipmi_demangle_device_id(resp, size - 2, &smi->device_id);
}

static int ipmi_i2c_get_devid(struct ipmi_smi_i2c *smi)
{
	struct ipmb_msg *ipmb_msg;
	int rc;
	int size;

	dev_dbg(&smi->client->dev, "%s\n", __func__);

	ipmb_msg = &smi->msg->ipmb;
	ipmb_msg->netfn = IPMI_NETFN_APP_REQUEST << 2;
	ipmb_msg->cmd = IPMI_GET_DEVICE_ID_CMD;
	ipmb_msg->seq = 1;
	/* workaround for Emerson firmware (7 bit Vs 8 bit slave addr notation) */
	ipmb_msg->slave = smi->client->addr << 1;
	ipmb_msg->response = smi->slave->addr << 1;
	ipmb_msg->hdr_crc = ipmi_crc(smi->msg->raw, 2);
	ipmb_msg->r.eq.cmd_crc = ipmi_crc(smi->msg->raw + 3, 3);

	/* data_size already includes the netfn and cmd bytes and
	   smbus excludes slave address and command as first byte */
	size = sizeof(*ipmb_msg) - 2;

	smi->response = ipmi_devid_recv;

	rc = i2c_smbus_write_i2c_block_data(smi->client,
					    smi->msg->raw[1],
					    size,
					    smi->msg->raw + 2);

	dev_dbg(&smi->client->dev, "%s: sent (%02x,%02x) %d, %d\n", __func__, ipmb_msg->netfn, ipmb_msg->cmd, size, rc);
	return rc;
}

static void ipmi_i2c_request_events(void *send_info)
{
}

static void ipmi_i2c_set_run_to_completion(void *send_info,
		bool run_to_completion)
{
	printk("\n\nSET RUN TO COMPLETION: %d\n\n", run_to_completion);
}

static void ipmi_i2c_poll(void *send_info)
{
	struct ipmi_smi_i2c *smi = send_info;

	dev_dbg(&smi->client->dev, "%s\n", __func__);
	ipmi_i2c_recv(smi);
}

static struct ipmi_smi_handlers ipmi_i2c_smi_handlers = {
	.owner			= THIS_MODULE,
	.start_processing	= ipmi_i2c_start_processing,
	.sender			= ipmi_i2c_send,
	.request_events		= ipmi_i2c_request_events,
	.set_run_to_completion	= ipmi_i2c_set_run_to_completion,
	.poll			= ipmi_i2c_poll,
};

static int i2c_ipmb_slave_cb(struct i2c_client *client,
			     enum i2c_slave_event event, u8 *val)
{
	struct ipmi_smi_i2c *smi = i2c_get_clientdata(client);

	switch (event) {
	case I2C_SLAVE_WRITE_RECEIVED:
		smi->msg->raw[smi->buf_off++] = *val;
		break;

	case I2C_SLAVE_READ_PROCESSED:
		break;

	case I2C_SLAVE_READ_REQUESTED:
		break;

	case I2C_SLAVE_STOP:
		smi->response(smi);
		break;

	case I2C_SLAVE_WRITE_REQUESTED:
		smi->buf_off = 1;
		break;

	default:
		break;
	}

	return 0;
}

static int ipmi_i2c_probe(struct i2c_client *client, const struct i2c_device_id *id)
{
	struct ipmi_smi_i2c *ipmi;
	struct device *dev;
	u32 prop;
	int rc;

	struct i2c_board_info info = {
		I2C_BOARD_INFO("i2c-ipmb-slave", 0)
	};

	printk("IPMB I2C probe\n");
	dev = &client->dev;

	ipmi = devm_kzalloc(dev, sizeof(*ipmi), GFP_KERNEL);
	if (!ipmi)
		return -ENOMEM;

	rc = of_property_read_u32(dev->of_node, "slave-addr",
			&prop);
	if (rc) {
		prop = IPMI_BMC_SLAVE_ADDR;
	}
	ipmi->slave_addr = prop;
	info.addr = prop;

	spin_lock_init(&ipmi->msg_lock);

	ipmi->msg = devm_kmalloc(dev,
			sizeof(*ipmi->msg) + IPMI_MAX_MSG_LENGTH,
			GFP_KERNEL);
	if (!ipmi->msg) {
		rc = -ENOMEM;
		goto err_free;
	}

	ipmi->client = client;
	ipmi->slave = i2c_new_device(to_i2c_adapter(client->dev.parent),
				     &info);
	ipmi->slave->flags |= I2C_CLIENT_SLAVE;

	rc = i2c_slave_register(ipmi->slave, i2c_ipmb_slave_cb);
	if (rc) {
		goto err_free_msg;
	}
	i2c_set_clientdata(client, ipmi);
	i2c_set_clientdata(ipmi->slave, ipmi);

#if 0
	if (ipmi->slave_addr == IPMI_BMC_SLAVE_ADDR) {
		init_completion(&ipmi->cmd_complete);
		rc = ipmi_i2c_get_devid(ipmi);
		if (rc)
			goto err_free;
		dev_dbg(dev, "wait for %lu\n", IPMI_TIMEOUT_JIFFIES);
		rc = wait_for_completion_interruptible_timeout(&ipmi->cmd_complete,
							       IPMI_TIMEOUT_JIFFIES);
		if (rc == 0) {
			printk("Get Device ID timed out\n");
//			rc = -ETIMEDOUT;
//			goto err_free;
		}
	}
#endif
	dev_dbg(dev, "do register\n");

	setup_timer(&ipmi->timer, ipmi_i2c_timeout, (long)ipmi);

	rc = ipmi_register_smi(&ipmi_i2c_smi_handlers, ipmi,
			&ipmi->device_id, dev, ipmi->slave_addr << 1);
	dev_dbg(dev, "ipmi_register_smi: %d\n", rc);
	if (rc) {
		dev_warn(dev, "IPMI SMI registration failed (%d)\n", rc);
		goto err_free_msg;
	}

	return 0;

err_free_msg:
	i2c_slave_unregister(ipmi->slave);
//	devm_kfree(dev, ipmi->opal_msg);
err_free:
	devm_kfree(dev, ipmi);
	return rc;
}

static int ipmi_i2c_remove(struct i2c_client *client)
{
	struct ipmi_smi_i2c *smi = i2c_get_clientdata(client);

	del_timer_sync(&smi->timer);
	i2c_slave_unregister(smi->slave);
	ipmi_unregister_smi(smi->intf);
	device_unregister(&smi->slave->dev);

	return 0;
}

static const struct i2c_device_id i2c_ipmb_slave_id[] = {
	{ "i2c-ipmb-slave", 0 },
	{ },
};

static int i2c_ipmb_slave_probe(struct i2c_client *client,
			        const struct i2c_device_id *id)
{
	printk("IPMB Slave probe\n");
	return 0;
}

static int i2c_ipmb_slave_remove(struct i2c_client *client)
{
	return 0;
}

static struct i2c_driver i2c_ipmb_slave_driver = {
	.driver.name	= "i2c-ipmb-slave",
	.probe		= i2c_ipmb_slave_probe,
	.remove		= i2c_ipmb_slave_remove,
	.id_table	= i2c_ipmb_slave_id,
};

static const struct i2c_device_id ipmi_i2c_ids[] = {
	{ "i2c-ipmb", 0 },
	{ },
};
MODULE_DEVICE_TABLE(i2c, ipmi_i2c_ids);

static struct i2c_driver i2c_ipmi_driver = {
	.driver = {
		.name		= "ipmi-i2c",
	},
	.probe	= ipmi_i2c_probe,
	.remove	= ipmi_i2c_remove,
	.id_table = ipmi_i2c_ids,
};

static int __init ipmi_i2c_init(void)
{
	int rc;
	rc = i2c_add_driver(&i2c_ipmb_slave_driver);
	if (rc) { printk("i2c_add_driver(&i2c_ipmb_slave_driver): %d\n", rc);
		goto err_out;
	}
	rc = i2c_add_driver(&i2c_ipmi_driver);
	if (rc)
		i2c_del_driver(&i2c_ipmb_slave_driver);
err_out:
	if (rc != 0) printk("IPMI i2C init: %d\n", rc);
	return rc;
}

static void __exit ipmi_i2c_exit(void)
{
	i2c_del_driver(&i2c_ipmi_driver);
	i2c_del_driver(&i2c_ipmb_slave_driver);
}

postcore_initcall(ipmi_i2c_init);
module_exit(ipmi_i2c_exit);

MODULE_DESCRIPTION("I2C IPMI driver");
MODULE_AUTHOR("Anton D. Kachalov <mouse@yandex-team.ru>");
MODULE_LICENSE("GPL");
