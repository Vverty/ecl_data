CREATE SCHEMA ecl_data;
USE ecl_data;
CREATE TABLE business_types ##tabla de tipos de negocio (persona humana, sociedad anónima, SRL, sociedad de hecho, etc)
(
    id_business_type INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_type_description VARCHAR(50) NOT NULL
);
CREATE TABLE industries ## Tabla de listado de industrias.
(
    id_industry INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    industry_description VARCHAR(100) NOT NULL
);
CREATE TABLE tax_regimes ## Tabla de regimenes tributarios como monotributo, regimen general, regimen de exportacion, jubilado, exento, etc
(
    id_tax_regime INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tax_regime_description VARCHAR(100) NOT NULL
);
CREATE TABLE clients ##Posee los datos de los clientes del estudio contable. id, fecha de creación, cuit, id tipo de negocio, id industria, nombre de negocio/razon social y id regimen tributario.
(
    id_client INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    client_name VARCHAR(100) DEFAULT 'SIN NOMBRE',
    cuit INT NOT NULL,
    id_business_type INT DEFAULT 1,
    id_industry INT DEFAULT 1,
    id_tax_regime INT DEFAULT 1,
    onboarding_date DATE NOT NULL,
    is_current_client BOOLEAN DEFAULT TRUE,
    exit_date DATE DEFAULT '2099-12-31',
    FOREIGN KEY(id_business_type) REFERENCES business_types(id_business_type),
    FOREIGN KEY(id_industry) REFERENCES industries(id_industry),
    FOREIGN KEY(id_tax_regime) REFERENCES tax_regimes(id_tax_regime)
);
CREATE TABLE agencies ##Tabla de listado de agencias o entidades responsables de los cargos.
(
    id_agency INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    agency_description VARCHAR(80) NOT NULL
);
CREATE TABLE charges ## Tabla de listado de impuestos o cargos. IVA, Ganancias, honorarios estudio contable, ingresos brutos, etc
(
    id_charge INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    charge_description VARCHAR(80) NOT NULL,
    id_agency INT DEFAULT 1,
    FOREIGN KEY(id_agency) REFERENCES agencies(id_agency)
);
CREATE TABLE out_payments ## Tabla de pagos de impuestos o cargos realizados por el estudio en nombre de clientes, como asi tambien pagos del estudio propios.
(
    id_outpay INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    payment_date DATE NOT NULL, 
    id_client INT NOT NULL,
    id_charge INT DEFAULT 1,
    amount NUMERIC DEFAULT 0,
    FOREIGN KEY (id_client) REFERENCES clients(id_client),
    FOREIGN KEY (id_charge) REFERENCES charges(id_charge)
);
CREATE TABLE in_payments ##tabla de cobros de dinero realizados por el estudio asociados a clientes
(
    id_inpay INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    receipt_date DATE NOT NULL, 
    id_client INT NOT NULL,
    amount NUMERIC DEFAULT 0,
    FOREIGN KEY (id_client) REFERENCES clients(id_client)
);
CREATE TABLE liabilities ##Tabla de presupúestación e imputación de obligaciones a clientes. Ya sea honorarios, cargos o impuestos.
(
    id_liability INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    due_date DATE NOT NULL, 
    id_client INT NOT NULL,
    id_charge INT DEFAULT 1,
    amount NUMERIC DEFAULT 0,
    FOREIGN KEY (id_client) REFERENCES clients(id_client),
    FOREIGN KEY (id_charge) REFERENCES charges(id_charge)
);
