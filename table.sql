CREATE TABLE public.country
(
    countrycode integer NOT NULL DEFAULT nextval('country_countrycode_seq'::regclass),
    countryname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT country_pkey PRIMARY KEY (countrycode),
    CONSTRAINT country_countryname_key UNIQUE (countryname)
);

CREATE TABLE public.port
(
    portid integer NOT NULL DEFAULT nextval('port_portid_seq'::regclass),
    latitude numeric(6,4) NOT NULL,
    longitude numeric(7,4) NOT NULL,
    portname character varying(200) COLLATE pg_catalog."default" NOT NULL,
    staycost numeric(9,2) NOT NULL,
    unloadcost numeric(9,2) NOT NULL,
    countrycode integer NOT NULL,
    CONSTRAINT port_pkey PRIMARY KEY (portid),
    CONSTRAINT port_latitude_longitude_key UNIQUE (latitude, longitude),
    CONSTRAINT port_portname_key UNIQUE (portname),
    CONSTRAINT port_countrycode_fkey FOREIGN KEY (countrycode)
        REFERENCES public.country (countrycode) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT port_latitude_check CHECK (latitude >= '-90.0000'::numeric AND latitude <= 90.0000),
    CONSTRAINT port_longitude_check CHECK (longitude >= '-180.0000'::numeric AND longitude <= 180.0000),
    CONSTRAINT port_staycost_check CHECK (staycost > 0::numeric),
    CONSTRAINT port_unloadcost_check CHECK (unloadcost > 0::numeric)
);

CREATE TABLE public.cruise
(
    cruiseid integer NOT NULL DEFAULT nextval('cruise_cruiseid_seq'::regclass),
    depdate date NOT NULL,
    ardate date NOT NULL,
    distance numeric(10,1) NOT NULL,
    warships integer NOT NULL DEFAULT 0,
    CONSTRAINT cruise_pkey PRIMARY KEY (cruiseid),
    CONSTRAINT cruise_check CHECK (ardate > depdate),
    CONSTRAINT cruise_distance_check CHECK (distance > 0::numeric),
    CONSTRAINT cruise_warships_check CHECK (warships < 21 AND warships >= 0)
);

CREATE TABLE public.portincruise
(
    numberincruise integer NOT NULL DEFAULT nextval('portincruise_numberincruise_seq'::regclass),
    cruiseid integer NOT NULL,
    portid integer NOT NULL,
    CONSTRAINT portincruise_pkey PRIMARY KEY (numberincruise),
    CONSTRAINT portincruise_cruiseid_fkey FOREIGN KEY (cruiseid)
        REFERENCES public.cruise (cruiseid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT portincruise_portid_fkey FOREIGN KEY (portid)
        REFERENCES public.port (portid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

CREATE TABLE public.captain
(
    captainid integer NOT NULL DEFAULT nextval('captain_captainid_seq'::regclass),
    passeries integer NOT NULL,
    pasnumber integer NOT NULL,
    lname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    fname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    patr character varying(30) COLLATE pg_catalog."default" NOT NULL,
    seniority integer NOT NULL DEFAULT 0,
    permiss boolean NOT NULL,
    CONSTRAINT captain_pkey PRIMARY KEY (captainid),
    CONSTRAINT captain_passeries_pasnumber_key UNIQUE (passeries, pasnumber),
    CONSTRAINT captain_pasnumber_check CHECK (pasnumber >= 100000 AND pasnumber <= 999999),
    CONSTRAINT captain_passeries_check CHECK (passeries >= 1000 AND passeries <= 9999),
    CONSTRAINT captain_seniority_check CHECK (seniority >= 0)
);

CREATE TABLE public.cargotype
(
    typeid integer NOT NULL DEFAULT nextval('cargotype_typeid_seq'::regclass),
    typename character varying(50) COLLATE pg_catalog."default" NOT NULL,
    costcoef numeric(5,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT cargotype_pkey PRIMARY KEY (typeid),
    CONSTRAINT cargotype_typename_key UNIQUE (typename),
    CONSTRAINT cargotype_costcoef_check CHECK (costcoef >= 0.00)
);

CREATE TABLE public.cargo
(
    cargoid integer NOT NULL DEFAULT nextval('cargo_cargoid_seq'::regclass),
    typeid integer NOT NULL,
    CONSTRAINT cargo_pkey PRIMARY KEY (cargoid),
    CONSTRAINT cargo_typeid_fkey FOREIGN KEY (typeid)
        REFERENCES public.cargotype (typeid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

CREATE TABLE public.ship
(
    shipid integer NOT NULL DEFAULT nextval('ship_shipid_seq'::regclass),
    shipname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    shiptype character(4) COLLATE pg_catalog."default" NOT NULL,
    status character(3) COLLATE pg_catalog."default" NOT NULL,
    made date NOT NULL DEFAULT CURRENT_DATE,
    servcost numeric(9,2) NOT NULL DEFAULT 100.00,
    shiprank character(1) COLLATE pg_catalog."default" NOT NULL,
    typeid integer,
    tonnage numeric(9,3),
    transpcost numeric(9,3),
    CONSTRAINT ship_pkey PRIMARY KEY (shipid),
    CONSTRAINT ship_shipname_key UNIQUE (shipname),
    CONSTRAINT ship_typeid_fkey FOREIGN KEY (typeid)
        REFERENCES public.cargotype (typeid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ship_servcost_check CHECK (servcost > 0.00),
    CONSTRAINT ship_shiprank_check CHECK (shiprank = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar])),
    CONSTRAINT ship_shiptype_check CHECK (shiptype = ANY (ARRAY['carg'::bpchar, 'pass'::bpchar])),
    CONSTRAINT ship_status_check CHECK (status = ANY (ARRAY['use'::bpchar, 'dec'::bpchar])),
    CONSTRAINT ship_tonnage_check CHECK (tonnage > 0::numeric),
    CONSTRAINT ship_transpcost_check CHECK (transpcost > 0::numeric)
);

CREATE TABLE public.shipincruise
(
    cruiseid integer NOT NULL,
    shipid integer NOT NULL,
    captainid integer NOT NULL,
    CONSTRAINT shipincruise_pkey PRIMARY KEY (cruiseid, shipid),
    CONSTRAINT shipincruise_cruiseid_captainid_key UNIQUE (cruiseid, captainid),
    CONSTRAINT shipincruise_captainid_fkey FOREIGN KEY (captainid)
        REFERENCES public.captain (captainid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipincruise_cruiseid_fkey FOREIGN KEY (cruiseid)
        REFERENCES public.cruise (cruiseid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipincruise_shipid_fkey FOREIGN KEY (shipid)
        REFERENCES public.ship (shipid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

CREATE TABLE public.client
(
    clientid integer NOT NULL DEFAULT nextval('client_clientid_seq'::regclass),
    passeries integer NOT NULL,
    pasnumber integer NOT NULL,
    lname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    fname character varying(30) COLLATE pg_catalog."default" NOT NULL,
    patr character varying(30) COLLATE pg_catalog."default" NOT NULL,
    photo character varying(500) COLLATE pg_catalog."default" NOT NULL DEFAULT 'https://arbooz.org/wp-content/uploads/sites/24/2015/09/Murzik-nuzhno-sfotografirovatsya-na-pasport..jpg'::character varying,
    CONSTRAINT client_pkey PRIMARY KEY (clientid),
    CONSTRAINT client_passeries_pasnumber_key UNIQUE (passeries, pasnumber),
    CONSTRAINT client_pasnumber_check1 CHECK (pasnumber >= 100000 AND pasnumber <= 999999),
    CONSTRAINT client_passeries_check CHECK (passeries >= 1000 AND passeries <= 9999)
);

CREATE TABLE public.shipmanifest
(
    manifestid integer NOT NULL DEFAULT nextval('shipmanifest_manifestid_seq'::regclass),
    shipid integer NOT NULL,
    clientid integer NOT NULL,
    fromport integer NOT NULL,
    toport integer NOT NULL,
    totalcost numeric(8,2) NOT NULL,
    paymentdate date,
    CONSTRAINT shipmanifest_pkey PRIMARY KEY (manifestid),
    CONSTRAINT shipmanifest_clientid_fkey FOREIGN KEY (clientid)
        REFERENCES public.client (clientid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifest_fromport_fkey FOREIGN KEY (fromport)
        REFERENCES public.portincruise (numberincruise) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifest_shipid_fkey FOREIGN KEY (shipid)
        REFERENCES public.ship (shipid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifest_toport_fkey FOREIGN KEY (toport)
        REFERENCES public.portincruise (numberincruise) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifest_totalcost_check CHECK (totalcost > 0.00)
);

CREATE TABLE public.shipmanifestrow
(
    manifestid integer NOT NULL,
    cargoid integer NOT NULL,
    weight numeric(9,3) NOT NULL,
    CONSTRAINT shipmanifestrow_cargoid_fkey FOREIGN KEY (cargoid)
        REFERENCES public.cargo (cargoid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifestrow_manifestid_fkey FOREIGN KEY (manifestid)
        REFERENCES public.shipmanifest (manifestid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT shipmanifestrow_weight_check CHECK (weight > 0.000)
);

CREATE TABLE public.decommissionreason
(
    reasonid integer NOT NULL DEFAULT nextval('decommissionreason_reasonid_seq'::regclass),
    reasonname character varying(200) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT decommissionreason_pkey PRIMARY KEY (reasonid),
    CONSTRAINT decommissionreason_reasinname_key UNIQUE (reasonname)
);

CREATE TABLE public.actofdecommission
(
    actid integer NOT NULL,
    shipid integer NOT NULL,
    decommissiondate date NOT NULL DEFAULT CURRENT_DATE,
    reasonid integer NOT NULL,
    CONSTRAINT actofdecommission_pkey PRIMARY KEY (actid, shipid),
    CONSTRAINT actofdecommission_shipid_key UNIQUE (shipid),
    CONSTRAINT actofdecommission_reasonid_fkey FOREIGN KEY (reasonid)
        REFERENCES public.decommissionreason (reasonid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT actofdecommission_shipid_fkey FOREIGN KEY (shipid)
        REFERENCES public.ship (shipid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

CREATE TABLE public.cabintype
(
    typeid integer NOT NULL DEFAULT nextval('cabintype_typeid_seq'::regclass),
    typename character varying(40) COLLATE pg_catalog."default" NOT NULL,
    seats integer NOT NULL,
    transpcost numeric(8,2) NOT NULL,
    CONSTRAINT cabintype_pkey PRIMARY KEY (typeid),
    CONSTRAINT cabintype_typename_key UNIQUE (typename),
    CONSTRAINT cabintype_seats_check CHECK (seats > 0 AND seats < 5),
    CONSTRAINT cabintype_transpcost_check CHECK (transpcost > 0::numeric)
);

CREATE TABLE public.cabin
(
    shipid integer NOT NULL,
    cabinid integer NOT NULL,
    typeid integer NOT NULL,
    CONSTRAINT cabin_pkey PRIMARY KEY (shipid, cabinid),
    CONSTRAINT cabin_shipid_fkey FOREIGN KEY (shipid)
        REFERENCES public.ship (shipid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT cabin_typeid_fkey FOREIGN KEY (typeid)
        REFERENCES public.cabintype (typeid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT cabin_cabinid_check CHECK (cabinid > 0)
);

CREATE TABLE public.ticket
(
    ticketid integer NOT NULL DEFAULT nextval('ticket_ticketid_seq'::regclass),
    clientid integer NOT NULL,
    fromport integer NOT NULL,
    toport integer NOT NULL,
    shipid integer NOT NULL,
    cabinid integer NOT NULL,
    ticketcost numeric(8,2) NOT NULL,
    paymentdate date,
    CONSTRAINT ticket_pkey PRIMARY KEY (ticketid),
    CONSTRAINT ticket_clientid_fkey FOREIGN KEY (clientid)
        REFERENCES public.client (clientid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ticket_fromport_fkey FOREIGN KEY (fromport)
        REFERENCES public.portincruise (numberincruise) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ticket_shipid_cabinid_fkey FOREIGN KEY (cabinid, shipid)
        REFERENCES public.cabin (cabinid, shipid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ticket_toport_fkey FOREIGN KEY (toport)
        REFERENCES public.portincruise (numberincruise) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ticket_ticketcost_check CHECK (ticketcost > 0.00)
)