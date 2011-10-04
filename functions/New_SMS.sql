CREATE OR REPLACE FUNCTION New_SMS( _PhoneNumber varchar, _Message varchar, _SMSSender text ) RETURNS INTEGER AS $BODY$
DECLARE
BEGIN
-- Dummy function, replace with something inserting the SMS into a queue and NOTIFY some application
RETURN 1;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
