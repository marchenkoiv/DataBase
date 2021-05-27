CREATE OR REPLACE PROCEDURE BuyTicket (
    p_ticketid integer,
    p_clientid integer,
    p_fromport integer,
    p_toport integer,
    p_shipid integer,
    p_cabinid integer,
    p_paymentdate date
) AS $$
DECLARE
  v_seats int;
  v_cost numeric(8,2);
  v_neighbors int;
  v_port int;
  v_departure date;
  v_dist int DEFAULT 0;
BEGIN

	SELECT cabintype.seats, cabintype.transpcost INTO v_seats, v_cost
      FROM cabintype
      INNER JOIN cabin
      ON cabin.typeid = cabintype.typeid
      WHERE cabin.shipid = p_shipid AND cabin.cabinid = p_cabinid;

	SELECT cruise.depdate INTO v_departure
      FROM cruise
      INNER JOIN portincruise
      ON cruise.cruiseid = portincruise.cruiseid
      WHERE numberincruise = p_fromport;

	FOR v_port IN
		SELECT portincruise.numberincruise
		FROM portincruise
		WHERE portincruise.numberincruise >= p_fromport AND portincruise.numberincruise < p_toport --считаем для каждого конкретного порта
	ORDER BY 1
	LOOP
	  SELECT COUNT(*) into v_neighbors
	  FROM ticket
      WHERE ticket.shipid = p_shipid AND ticket.cabinid = p_cabinid AND ticket.fromport <= v_port AND ticket.toport > v_port AND NOT (ticket.paymentdate is NULL AND p_paymentdate + 7 > v_departure );
	  	raise notice 'v_neighbors: %', v_neighbors;
		raise notice 'v_port: %', v_port;
	  IF v_neighbors >= v_seats
		THEN
		RAISE EXCEPTION 'Каюта укомплектована на этом участке маршрута';
	  END IF;
	  v_dist := v_dist + 1;
	END LOOP;

	IF p_paymentdate is NULL
	THEN v_cost := 0.01;
	END IF;
	raise notice 'v_cost: %', v_cost;

	INSERT INTO ticket
	VALUES (p_ticketid, p_clientid, p_fromport, p_toport, p_shipid, p_cabinid, v_cost*v_dist, p_paymentdate);

END;
$$ LANGUAGE plpgsql;



CREATE TYPE t_row AS (
    i       integer,
    w       numeric(9,3)
);


CREATE OR REPLACE PROCEDURE BuyManifest (
	p_shipid integer,
    p_clientid integer,
    p_fromport integer,
    p_toport integer,
    p_paymentdate date,
	p_cargo t_row ARRAY
)
AS $$
DECLARE
  p_manifestid integer;
  v_tonnage numeric(9,3);
  v_cost numeric(9,3);
  v_currentweight numeric(9,3);
  v_port int;
  v_departure date;
  v_dist int DEFAULT 0;
  v_maxweight numeric(9,3) DEFAULT 0.000;
  v_row t_row;
  v_cargoinrow int;
  v_shiptypeid int;
  v_costcoef numeric(5,2);
  v_unloadfrom numeric(9,2);
  v_unloadto numeric(9,2);
  c_cursor refcursor;
BEGIN

	SELECT ship.tonnage, ship.transpcost, ship.typeid INTO v_tonnage, v_cost, v_shiptypeid
      FROM ship
	  WHERE ship.shipid = p_shipid;

	  SELECT port.unloadcost INTO v_unloadfrom
      FROM port
      INNER JOIN portincruise
      ON port.portid = portincruise.portid
	  WHERE portincruise.numberincruise = p_fromport;

	  SELECT port.unloadcost INTO v_unloadto
      FROM port
      INNER JOIN portincruise
      ON port.portid = portincruise.portid
	  WHERE portincruise.numberincruise = p_toport;

	 SELECT cargotype.costcoef INTO v_costcoef
      FROM cargotype
      INNER JOIN ship
      ON ship.typeid = cargotype.typeid
	  WHERE ship.shipid = p_shipid;

	SELECT cruise.depdate INTO v_departure
      FROM cruise
      INNER JOIN portincruise
      ON cruise.cruiseid = portincruise.cruiseid
      WHERE numberincruise = p_fromport;

	OPEN c_cursor FOR SELECT portincruise.numberincruise
		FROM portincruise
		WHERE portincruise.numberincruise >= p_fromport AND portincruise.numberincruise < p_toport; --считаем для каждого конкретного порта
	LOOP
        FETCH c_cursor INTO v_port;
        IF NOT FOUND THEN EXIT;END IF;
	  SELECT SUM(shipmanifestrow.weight) into v_currentweight
	  FROM shipmanifest
	  INNER JOIN shipmanifestrow
      ON shipmanifest.manifestid = shipmanifestrow.manifestid
      WHERE shipmanifest.shipid = p_shipid AND shipmanifest.fromport <= v_port AND shipmanifest.toport > v_port AND NOT (shipmanifest.paymentdate is NULL AND p_paymentdate + 7 > v_departure );
	  raise notice 'v_currentweight: %', v_currentweight;
	  raise notice 'v_port: %', v_port;
	  IF v_currentweight >= v_tonnage
		THEN
		RAISE EXCEPTION 'Судно укомплектовано на этом участке маршрута';
	  END IF;
	  IF v_currentweight > v_maxweight
		THEN
		v_maxweight := v_currentweight;
	  END IF;
	  v_dist := v_dist + 1;
	END LOOP;
	CLOSE c_cursor;

	raise notice 'v_cost: %', v_cost;
	raise notice 'v_dist: %', v_dist;

	INSERT INTO shipmanifest (shipid, clientid, fromport, toport, totalcost, paymentdate)
	VALUES ( p_shipid, p_clientid, p_fromport, p_toport, v_cost*v_dist, p_paymentdate)
	RETURNING manifestid INTO p_manifestid;

	raise notice 'p_manifestid: %', p_manifestid;

	v_currentweight := 0.000;

	FOREACH v_row IN ARRAY p_cargo
	LOOP
		SELECT cargo.typeid INTO v_cargoinrow
			FROM cargo
      		WHERE (v_row).i = cargo.cargoid;
		v_currentweight := v_currentweight + (v_row).w;
		IF v_cargoinrow = v_shiptypeid AND v_currentweight + v_maxweight <= v_tonnage
		THEN
			INSERT INTO shipmanifestrow
			VALUES (p_manifestid, (v_row).i, (v_row).w);
		ELSE
			raise notice 'Груз не может быть добавлен, id груза - %', (v_row).i;
			v_currentweight := v_currentweight - (v_row).w;
		END IF;
    END LOOP;

	IF p_paymentdate is NULL
	THEN v_cost := 0.01;
	v_unloadfrom := 0.01;
	v_unloadto := 0.01;
	END IF;

	raise notice 'итого стоимость перевозки - %', round((v_cost * v_dist * v_currentweight + (v_unloadfrom + v_unloadto) * (1 + v_costcoef/100)), 2);

	UPDATE shipmanifest
	SET totalcost = round((v_cost * v_dist * v_currentweight + (v_unloadfrom + v_unloadto) * (1 + v_costcoef/100)), 2)
	WHERE manifestid = p_manifestid;

	raise notice 'Создана судовая декларация № %', p_manifestid;

END;
$$ LANGUAGE plpgsql;


