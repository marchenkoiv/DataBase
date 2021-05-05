CREATE OR REPLACE FUNCTION passenger_or_cargo() RETURNS TRIGGER AS $$
	BEGIN
		IF NOT(((new.shiptype LIKE 'carg') AND (new.typeid IS NOT NULL) AND (new.tonnage IS NOT NULL) AND (new.transpcost IS NOT NULL)) OR
		((new.shiptype LIKE 'pass') AND (new.typeid IS NULL) AND (new.tonnage IS NULL) AND (new.transpcost IS NULL)))
		THEN
		RAISE EXCEPTION 'Тип судна не соответствует его атрибутам';
		END IF;
		RETURN NEW;
	END;
	$$ LANGUAGE plpgsql;

	CREATE TRIGGER passengerorcargo
	AFTER INSERT OR UPDATE ON Ship
	FOR EACH ROW EXECUTE PROCEDURE passenger_or_cargo();


CREATE OR REPLACE FUNCTION Captain_in_cruise() RETURNS TRIGGER AS $$
  DECLARE
  current_dep DATE;
  current_ar DATE;
  BEGIN
    SELECT cruise.depdate INTO current_dep
    FROM cruise WHERE cruise.cruiseid = new.cruiseid;
    raise notice 'depdate: %', current_dep;
    SELECT cruise.ardate INTO current_ar
    FROM cruise WHERE cruise.cruiseid = new.cruiseid;
    raise notice 'ardate: %', current_ar;
    IF EXISTS(
    SELECT cruise.cruiseid
      FROM cruise
      INNER JOIN shipincruise
      ON cruise.cruiseid = shipincruise.cruiseid
      WHERE captainid = new.captainid AND NOT(cruise.depdate > current_ar OR cruise.ardate < current_dep))
    THEN
    RAISE EXCEPTION 'Капитан уже участвует в рейсе в это время';
    END IF;
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  CREATE TRIGGER Captainincruise
  AFTER INSERT OR UPDATE ON Shipincruise
  FOR EACH ROW EXECUTE PROCEDURE Captain_in_cruise();