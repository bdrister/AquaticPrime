-- Sample tables that can be used to store everything received in an
-- eSellerate XML order notice.  Except where noted, field types and sizes are
-- based on "OrderNoticeDS.xsd" and "OrderNoticeDS.xsd Reference.pdf".
-- The tables were designed to target MySQL 4.1.18, and may or may not need
-- customizing for other database engines.

-- These tables include everything from the XML post (except where noted).
-- However all fields except ORDER_NUMBER (in OrderInfo) and SKU_ID (in OrderLines)
-- are allowed to be NULL, so you can choose to just not populate fields you're not interested in.
-- In particular if you just want to set up a password-retreival database, you might
-- want to leave out everything except serial number and email address.

-- Tom Harrington, tph@atomicbird.com, May 5 2006

-- (details on MySQL foreign key syntax: http://dev.mysql.com/doc/refman/4.1/en/innodb-foreign-key-constraints.html)

-- $Id: eSellerate.sql 210 2007-09-06 23:19:09Z atomicbird $
DROP TABLE IF EXISTS OrderLines;
DROP TABLE IF EXISTS OrderInfo;
DROP TABLE IF EXISTS SNLookupHistoryEntry;

-- OrderInfo has general information about the order and the customer
-- Note the following fields from the XML post are intentionally left out as not being useful here:
--	ORDER_NOTICE_SECRET
--	ORDER_NOTICE_URL
--	PUBLISHER_ID
--	PUBLISHER
CREATE TABLE OrderInfo (
		CUSTOMER_IP	CHAR(50),
		ORDER_NUMBER	CHAR(50) NOT NULL,
			PRIMARY KEY (ORDER_NUMBER),
		STATUS		CHAR(50),
		TRAN_DATE	DATE,	-- eSellerate defines this as a string up to 50 chars long.
		FIRST_NAME	CHAR(50),
		LAST_NAME	CHAR(50),
		COMPANY		CHAR(50),
		ADDRESS1	CHAR(100),
		ADDRESS2	CHAR(100),
		CITY		CHAR(50),
		STATE		CHAR(50),
		POSTAL		CHAR(50),
		COUNTRY		CHAR(50),
		PHONE		CHAR(50),
		EMAIL		CHAR(50),
		SHIP_FIRST_NAME	CHAR(50),
		SHIP_LAST_NAME	CHAR(50),
		SHIP_COMPANY	CHAR(50),
		SHIP_ADDRESS1	CHAR(100),
		SHIP_ADDRESS2	CHAR(100),
		SHIP_CITY	CHAR(50),
		SHIP_STATE	CHAR(50),
		SHIP_POSTAL	CHAR(50),
		SHIP_COUNTRY	CHAR(50),
		CONTACT_ME	TINYINT,
		ORDER_DISCOUNT	DECIMAL(10,2),
		SHIP_WEIGHT	DECIMAL(10,2),
		SHIP_METHOD	CHAR(50),
		SHIP_AMOUNT	DECIMAL(10,2),
		ESELLER_ID	CHAR(50),
		ESELLER_NAME	CHAR(50),
		METHOD		CHAR(50),
		SUB_METHOD	CHAR(50),
		COUPON_ID	CHAR(100),
		TRACKING_ID	TEXT,		-- Changed to TEXT because eSellerate's length of 4000 is too long for CHAR
		VAT_COUNTRY	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CURRENCY_CODE	CHAR(10),
		AFFILIATE_ID	CHAR(50),
		AFFILIATE_NAME	CHAR(50),
		PORTAL_ID	CHAR(50),
		PORTAL_NAME	CHAR(50),
		CUSTOM_0	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_1	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_2	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_3	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_4	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_5	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_6	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_7	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_8	TEXT,		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
		CUSTOM_9	TEXT		-- Changed to TEXT because eSellerate's length of 1000 is too long for CHAR
) ENGINE=InnoDB;

-- OrderLines has information about each of the SKUs in the order.
CREATE TABLE OrderLines (
		SKU_ID			CHAR(50) NOT NULL,
		SKU_TITLE		CHAR(255),
		SHORT_DESCRIPTION	CHAR(255),
		QUANTITY		INT,
		UNIT_PRICE		DECIMAL(10,2),
		PLATFORM		CHAR(50),
		REGISTRATION_NAME	CHAR(100),
		PROMPTED_VALUE		CHAR(255),
		REGISTRATION_OTHER	CHAR(255),
		EXPIRATION_DATE		CHAR(50),
		SERIAL_NUMBER		TEXT,	-- raised this from 255 so I could put Aquatic Prime SNs in there.
		PROCESSING_FEE		DECIMAL(10,2),
		SALES_TAX_AMOUNT	DECIMAL(10,2),
		AFFILIATE_COMMISION	DECIMAL(10,2),
		VOLUME_DISCOUNT		DECIMAL(10,2),
		CROSS_SELL_DISCOUNT	DECIMAL(10,2),
		UP_SELL_GROUP_ID	INT,
		UP_SELL_PARENT_SKU_ID	CHAR(50),

		SN_LOOKUP_COUNT		INT DEFAULT 0,		-- number of times a specific SN has been looked up

		ORDER_NUMBER		CHAR(50) NOT NULL,

		SN_DATE			DATETIME,

		FOREIGN KEY(ORDER_NUMBER) REFERENCES OrderInfo(ORDER_NUMBER),
		PRIMARY KEY(ORDER_NUMBER,SKU_ID)
) ENGINE=InnoDB;

-- SN Lookup records:
-- Each lookup may affect more than one SN (if there's more than one SN with the same email address).
-- Each SN may have been looked up more than one time (which is why we keep a count).

-- If someone is looking up SNs, they should receive all SNs associated with their email address.
-- If a particular SN has been looked up too many times, it should be locked out.

-- Just a record that the SN was looked up
CREATE TABLE SNLookupHistoryEntry (
		LOOKUP_ID		INT NOT NULL AUTO_INCREMENT,
			PRIMARY KEY(LOOKUP_ID),
		-- We don't use real referential integrity on SERIAL_NUMBER because you can't do that
		-- with TEXT (no known key length), but the fixed-length string types are too short.
		SERIAL_NUMBER		TEXT NOT NULL REFERENCES OrderLines(SERIAL_NUMBER),
		LOOKUP_DATE		DATETIME,
		SUCCESS			TINYINT DEFAULT 0
) ENGINE=InnoDB;

-- Looking up SNs without views (since we're assuming MySQL, which is too stupid to support views in the
-- versions commonly found on web hosts).
--	Look up results for email address using the following SELECT.
--	If results found,
	-- For each SN,
		-- increment lookup count for the SN in OrderLines
		-- if lookup count <= N, send SN
		-- Create a new SNLookupHistory entry with "success" value depending on whether SN was sent

-- Look up SNs using this view.  
-- For each SN found:
--	Increment lookup_count
--	If lookup_count <= N, send SN
--	Create a new SNLookupHistory entry with "success" value depending on whether SN was sent
--CREATE VIEW SNLookup AS
