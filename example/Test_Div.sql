CREATE OR REPLACE FUNCTION Test_Div(_X numeric, _Y numeric) RETURNS NUMERIC AS $BODY$
DECLARE
BEGIN

RAISE NOTICE 'NOTICE_TEST Called with parameters X % and Y %', _X, _Y;

IF _X = 0 THEN
    RAISE WARNING 'WARNING_ZERO Parameters X is zero';
END IF;

IF _X < 0 THEN
    RAISE EXCEPTION 'ERROR_NEG Parameter X is negative';
END IF;

RETURN _X / _Y;

END;
$BODY$ LANGUAGE plpgsql;
