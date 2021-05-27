--1

SELECT ship.shipid,
		ship.shipname,
		count(DISTINCT shipincruise.cruiseid),
		ship.shiptype,
		ship.status,
		COALESCE(NULLIF (count(DISTINCT shipmanifest.manifestid), 0), count(DISTINCT ticket.ticketid)),
		COALESCE(sum(DISTINCT shipmanifest.totalcost), sum(DISTINCT ticket.ticketcost), 0)
FROM ship
LEFT JOIN ticket
ON ship.shipid = ticket.shipid
LEFT JOIN shipmanifest
ON shipmanifest.shipid=ship.shipid
LEFT JOIN shipmanifestrow
ON shipmanifestrow.manifestid=shipmanifest.manifestid
LEFT JOIN shipincruise
ON shipincruise.shipid=ship.shipid
GROUP BY ship.shipid
--2
WITH cap AS(
SELECT captain.captainid,
	count (DISTINCT shipincruise.cruiseid) as "num"
	FROM captain
	INNER JOIN shipincruise
	ON captain.captainid=shipincruise.captainid
	GROUP BY captain.captainid
), carg AS(
SELECT ship.shipid
	FROM ship
	WHERE ship.shiptype LIKE 'carg'
), pass AS(
SELECT ship.shipid
	FROM ship
	WHERE ship.shiptype LIKE 'pass'
)
SELECT  captain.captainid,
		captain.lname,
		captain.fname,
		captain.patr,
		count(DISTINCT carg.shipid) as "carg",
		count(DISTINCT pass.shipid) as "pass",
		count(portincruise.numberincruise) as "ports",
		count(DISTINCT port.countrycode) as "countries"
FROM captain
INNER JOIN cap
ON cap.captainid=captain.captainid
INNER JOIN shipincruise
ON captain.captainid=shipincruise.captainid
LEFT JOIN carg
ON shipincruise.shipid=carg.shipid
LEFT JOIN pass
ON shipincruise.shipid=pass.shipid
INNER JOIN cruise
ON cruise.cruiseid = shipincruise.cruiseid
INNER JOIN portincruise
ON portincruise.cruiseid = cruise.cruiseid
INNER JOIN port
ON portincruise.portid = port.portid
WHERE cap.num = (SELECT max(cap.num) FROM cap)
GROUP BY captain.captainid

--3
WITH carg AS (
	SELECT DISTINCT portincruise.cruiseid as cruiseid,
		   COALESCE (sum(shipmanifest.totalcost), 0) as totalcost
	FROM portincruise
	INNER JOIN shipmanifest
	ON portincruise.numberincruise = shipmanifest.fromport
	WHERE shipmanifest.paymentdate is not NULL
	GROUP BY portincruise.cruiseid
),
pass AS (
	SELECT DISTINCT portincruise.cruiseid as cruiseid,
		   COALESCE (sum(ticket.ticketcost), 0) as totalcost
	FROM portincruise
	INNER JOIN ticket
	ON portincruise.numberincruise = ticket.fromport
	WHERE ticket.paymentdate is not NULL
	GROUP BY portincruise.cruiseid
)
SELECT DISTINCT cruise.cruiseid,
	   			cruise.depdate,
	   			cruise.ardate,
	   			cruise.distance,
	   			cruise.warships,
	   			(count (DISTINCT portincruise.numberincruise)) as "number of ports",
				count (DISTINCT shipincruise.shipid) + cruise.warships as "number of ships",
				COALESCE (pass.totalcost, 0) as "profit pass",
				COALESCE (carg.totalcost, 0) as "profit carg",
				COALESCE (pass.totalcost, 0) + COALESCE (carg.totalcost, 0) as "total profit"
FROM cruise
LEFT JOIN portincruise --INNER
ON cruise.cruiseid = portincruise.cruiseid
LEFT JOIN shipincruise --INNER
ON cruise.cruiseid = shipincruise.cruiseid
LEFT JOIN carg
ON cruise.cruiseid = carg.cruiseid
LEFT JOIN pass
ON cruise.cruiseid = pass.cruiseid
WHERE cruise.depdate > current_date - INTERVAL '1 year'
GROUP BY cruise.cruiseid, pass.totalcost, carg.totalcost
--4
SELECT client.clientid,
	   client.passeries,
	   client.pasnumber,
	   client.lname,
	   client.fname,
	   client.patr,
	   COALESCE (count(	DISTINCT shipmanifest.manifestid), 0) as "manifests",
	   COALESCE (count(DISTINCT ticket.ticketid), 0) as "tickets",
	   COALESCE (sum(DISTINCT ticket.toport-ticket.fromport+1),0)+COALESCE (sum(DISTINCT shipmanifest.toport-shipmanifest.fromport+1), 0) as "ports",
	   COALESCE (count(DISTINCT portincruise.cruiseid),0) as "cruises"
FROM client
LEFT JOIN shipmanifest
ON client.clientid = shipmanifest.clientid and shipmanifest.paymentdate is not NULL
LEFT JOIN ticket
ON client.clientid = ticket.clientid and ticket.paymentdate is not NULL
INNER JOIN portincruise --LEFT
ON portincruise.numberincruise = ticket.fromport or portincruise.numberincruise = shipmanifest.fromport
GROUP BY client.clientid
ORDER BY client.clientid
--5
WITH all_reasons as
		(SELECT  EXTRACT(YEAR FROM actofdecommission.decommissiondate) as "year",
		count(actofdecommission.actid) as "count",
		decommissionreason.reasonname as "reason"
FROM actofdecommission
INNER JOIN decommissionreason
ON actofdecommission.reasonid = decommissionreason.reasonid
WHERE actofdecommission.decommissiondate > current_date -  INTERVAL '5 years'
GROUP BY EXTRACT(YEAR FROM actofdecommission.decommissiondate), decommissionreason.reasonname
), popular as(
SELECT all_reasons.year as "year",
	string_agg(all_reasons.reason, ', ') as "reason"
FROM all_reasons
WHERE (all_reasons.count, all_reasons.year) IN (SELECT max(all_reasons.count),
												all_reasons.year
												FROM all_reasons
						   						GROUP BY all_reasons.year)
GROUP BY all_reasons.year
)
SELECT all_reasons.year,
		sum(all_reasons.count),
		popular.reason
FROM all_reasons
INNER JOIN popular
ON all_reasons.year = popular.year
GROUP BY all_reasons.year, popular.reason

