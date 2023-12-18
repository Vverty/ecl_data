CREATE SCHEMA ecl_data;
USE ecl_data;
CREATE TABLE business_types
(
    id_business_type INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_type_description VARCHAR(50) NOT NULL
);
CREATE TABLE industries
(
    id_industry INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    industry_description VARCHAR(100) NOT NULL
);
CREATE TABLE tax_regimes 
(
    id_tax_regime INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tax_regime_description VARCHAR(100) NOT NULL
);
CREATE TABLE clients
(
    id_client INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    client_name VARCHAR(100) DEFAULT NULL,
    cuit BIGINT NOT NULL,
    id_business_type INT DEFAULT NULL,
    id_industry INT DEFAULT NULL,
    id_tax_regime INT DEFAULT NULL,
    onboarding_date DATE NOT NULL,
    is_current_client BOOLEAN DEFAULT TRUE,
    exit_date DATE DEFAULT NULL,
    UNIQUE(cuit),
    FOREIGN KEY(id_business_type) REFERENCES business_types(id_business_type) ON DELETE RESTRICT,
    FOREIGN KEY(id_industry) REFERENCES industries(id_industry) ON DELETE RESTRICT,
    FOREIGN KEY(id_tax_regime) REFERENCES tax_regimes(id_tax_regime) ON DELETE RESTRICT,
    CHECK(LENGTH(cuit) >= 10 AND (cuit LIKE '2%' OR cuit LIKE '3%'))
);
CREATE TABLE agencies 
(
    id_agency INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    agency_description VARCHAR(80) NOT NULL
);
CREATE TABLE charges
(
    id_charge INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    charge_description VARCHAR(80) NOT NULL,
    id_agency INT DEFAULT NULL,
    FOREIGN KEY(id_agency) REFERENCES agencies(id_agency) ON DELETE RESTRICT
);
CREATE TABLE liabilities 
(
    id_liability INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    due_date DATE NOT NULL, 
    id_client INT NOT NULL,
    id_charge INT DEFAULT NULL,
    amount NUMERIC(15,2) DEFAULT 0,
    FOREIGN KEY(id_client) REFERENCES clients(id_client) ON DELETE RESTRICT,
    FOREIGN KEY(id_charge) REFERENCES charges(id_charge) ON DELETE RESTRICT,
    CHECK(amount >= 0)
);
CREATE TABLE in_payments 
(
    id_inpay INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    receipt_date DATE NOT NULL, 
    id_client INT NOT NULL,
    amount NUMERIC(15,2) DEFAULT 0,
    FOREIGN KEY(id_client) REFERENCES clients(id_client) ON DELETE RESTRICT,
    CHECK(amount >= 0)
);
CREATE TABLE out_payments 
(
    id_outpay INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    payment_date DATE NOT NULL, 
    id_client INT NOT NULL,
    id_charge INT DEFAULT NULL,
    amount NUMERIC(15,2) DEFAULT 0,
    FOREIGN KEY(id_client) REFERENCES clients(id_client) ON DELETE RESTRICT,
    FOREIGN KEY(id_charge) REFERENCES charges(id_charge) ON DELETE RESTRICT,
    CHECK(amount >= 0)
);
CREATE TABLE ecl_data_audits 
(
    id_log INT PRIMARY KEY AUTO_INCREMENT,
    entity VARCHAR(100),
    entity_id INT,
    created_date DATETIME,
    created_by VARCHAR(100),
    updated_date DATETIME,
    updated_by VARCHAR(100)
);
DELIMITER //
CREATE TRIGGER before_insert_liabilities
BEFORE INSERT ON liabilities
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER before_update_liabilities
BEFORE UPDATE ON liabilities
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER before_insert_in_payments
BEFORE INSERT ON in_payments
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER before_update_in_payments
BEFORE UPDATE ON in_payments
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER before_insert_out_payments
BEFORE INSERT ON out_payments
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER before_update_out_payments
BEFORE UPDATE ON out_payments
FOR EACH ROW
BEGIN
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END;
//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `insert_liability_aud`
AFTER INSERT ON liabilities
FOR EACH ROW
BEGIN
    INSERT INTO `ecl_data_audits`(entity, entity_id, created_date, created_by, updated_date, updated_by) 
    VALUES ('liability', NEW.id_liability, CURRENT_TIMESTAMP(), USER(), CURRENT_TIMESTAMP(), USER());
END;
CREATE TRIGGER `update_liability_aud`
AFTER UPDATE ON liabilities
FOR EACH ROW
BEGIN
    UPDATE `ecl_data_audits` SET updated_date = CURRENT_TIMESTAMP(), updated_by = USER() 
    WHERE entity_id = OLD.id_liability;
END;

//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `insert_in_payments_aud`
AFTER INSERT ON in_payments
FOR EACH ROW
BEGIN
    INSERT INTO `ecl_data_audits` (entity, entity_id, created_date, created_by, updated_date, updated_by) 
    VALUES ('in_payments', NEW.id_inpay, CURRENT_TIMESTAMP(), USER(), CURRENT_TIMESTAMP(), USER());
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `update_in_payments_aud`
AFTER UPDATE ON in_payments
FOR EACH ROW
BEGIN
    UPDATE `ecl_data_audits` SET updated_date = CURRENT_TIMESTAMP(), updated_by = USER() 
    WHERE entity_id = OLD.id_inpay;
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `insert_out_payments_aud`
AFTER INSERT ON out_payments
FOR EACH ROW
BEGIN
    INSERT INTO `ecl_data_audits` (entity, entity_id, created_date, created_by, updated_date, updated_by) 
    VALUES ('out_payments', NEW.id_outpay, CURRENT_TIMESTAMP(), USER(), CURRENT_TIMESTAMP(), USER());
END;
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `update_out_payments_aud`
AFTER UPDATE ON out_payments
FOR EACH ROW
BEGIN
    UPDATE `ecl_data_audits` SET updated_date = CURRENT_TIMESTAMP(), updated_by = USER() 
    WHERE entity_id = OLD.id_outpay;
END;
//
DELIMITER ;
## Crear una vista que muestra la suma de montos de las obligaciones agrupadas por descripción de la agencia
CREATE VIEW liabilities_per_agency AS
	(SELECT 
		DATE_FORMAT(L.due_date, '%Y-%m') AS row_period,
		A.agency_description, 
		SUM(L.amount) AS total_amount
	FROM liabilities AS L
	LEFT JOIN charges AS C 
		ON C.id_charge = L.id_charge
	LEFT JOIN agencies AS A 
		ON A.id_agency = C.id_agency
	GROUP BY 
		A.agency_description,
		row_period
	ORDER BY total_amount DESC);

## Crear una vista que muestra el estado de cuenta de los clientes
CREATE VIEW clients_account_statement AS
	(SELECT
    	C.id_client,
    	C.client_name,
    	C.cuit,
		((SELECT COALESCE(SUM(amount), 0) 
		FROM liabilities 
		WHERE id_client = C.id_client)
    		-
		(SELECT COALESCE(SUM(amount), 0)
		FROM in_payments 
		WHERE id_client = C.id_client))
    	AS account_balance
	FROM clients AS C
	ORDER BY account_balance DESC);

## Crear una vista que la recaudación por cliente
CREATE VIEW clients_monthly_receipts AS
	(SELECT
		DATE_FORMAT(I.receipt_date, '%Y-%m') AS row_period,
    	C.id_client,
    	C.client_name,
    	C.cuit,
    	SUM(I.amount) AS monthly_income
	FROM in_payments AS I
	INNER JOIN clients AS C 
		ON I.id_client = C.id_client
	GROUP BY 
		C.id_client, 
		row_period);

##Crear un listado de honorarios historico
CREATE VIEW clients_fees_history AS
	(SELECT
    	C.id_client,
    	C.client_name,
    	C.cuit,
    	L.due_date,
    	L.amount AS fee_amount
	FROM clients AS C
	LEFT JOIN liabilities AS L 
		ON C.id_client = L.id_client
	WHERE L.id_charge = 1);

## Listado de honorarios actual HAY QUE CORREGIRLO
CREATE VIEW clients_fees AS
	(SELECT
    	C.id_client,
    	C.client_name,
    	C.cuit,
    	C.due_date,
    	C.fee_amount
	FROM 
		(SELECT
			ROW_NUMBER () OVER(PARTITION BY C.id_client ORDER BY L.due_date DESC) AS RN,
    		C.id_client AS id_client,
    		C.client_name AS client_name,
    		C.cuit AS cuit,
    		L.due_date AS due_date,
    		L.amount AS fee_amount
		FROM clients AS C
		LEFT JOIN liabilities AS L 
			ON C.id_client = L.id_client
		WHERE L.id_charge = 1
			AND C.is_current_client = TRUE)
		AS C
	WHERE 1 = 1
		AND C.RN = 1);

##Saldo a tener en el banco segun fecha de vencimiento de impuestos de clientes que hayan pagado la totalidad de lo adeudado.

CREATE VIEW projected_bank_balance AS
	(SELECT
		L.due_date,
		SUM(L.amount) AS bank_balance
	FROM liabilities AS L
	WHERE 1 = 1 
		AND id_charge != 1
		AND L.id_client 
			IN
				(SELECT id_client
				FROM liabilities
				GROUP BY id_client
				HAVING SUM(amount) <=
					(SELECT SUM(amount)
					FROM in_payments AS I
					WHERE I.id_client = L.id_client))			
	GROUP BY L.due_date
	ORDER BY L.due_date);

## Listado de pagos a realizar

CREATE VIEW outpayment_worklist AS
	(SELECT
		C.id_client,
		C.client_name,
		C.cuit,
		CH.charge_description,
		A.agency_description,
		L.id_charge,
		L.amount,
		L.due_date
	FROM liabilities AS L
	INNER JOIN clients AS C 
		ON L.id_client = C.id_client
	INNER JOIN charges AS CH 
		ON L.id_charge = Ch.id_charge
	INNER JOIN agencies AS A 
		ON Ch.id_agency = A.id_agency
	WHERE 1 = 1
		AND L.id_client 
			IN 
				(SELECT id_client
				FROM liabilities
				GROUP BY id_client
				HAVING SUM(amount) <=
					(SELECT COALESCE(SUM(amount), 0)
					FROM in_payments AS I
					WHERE I.id_client = L.id_client))
		AND L.id_charge != 1
	ORDER BY L.due_date ASC);

####Genera estado de cuenta completo de algun cliente
DELIMITER //
CREATE FUNCTION generate_account_statement_history(client_id INT, start_date DATE, end_date DATE)
RETURNS TEXT
NO SQL
BEGIN
    DECLARE report TEXT;
    DECLARE initial_balance NUMERIC;
    DECLARE obligation_details TEXT;
    DECLARE final_balance NUMERIC;
    SET group_concat_max_len = 10000;
##Encabezado del estado de cuenta
    SET report = CONCAT('Estado de Cuenta del Cliente ID ', '>>> ', client_id, '\n');
    SET report = CONCAT(report, 'Período: ', start_date, ' - ', end_date, '\n\n');
##Saldo inicial = liabilities - inpayments
    SET initial_balance = 
        (SELECT COALESCE(SUM(amount), 0)
        FROM liabilities
        WHERE id_client = client_id 
            AND due_date < start_date)
        -
        (SELECT COALESCE(SUM(amount), 0)
        FROM in_payments
        WHERE id_client = client_id 
            AND receipt_date < start_date);       
    SET report = CONCAT(report, 'Saldo Inicial: ', initial_balance, '\n\n');
##Detalle de obligaciones y pagos dentro del rango de fechas
    SET obligation_details = (
        SELECT 
            GROUP_CONCAT(
                'Fecha de Vencimiento: ', due_date, 
                ' | Cargo: ', charge_description, 
                ' | Monto Presupuestado: ', amount,
                ' | Pagos Realizados: ', payment_amount,
                '\n' 
            SEPARATOR '')
        FROM 
            (SELECT 
                L.due_date, 
                C.charge_description, 
                L.amount, 
                CASE 
                WHEN O.amount IS NOT NULL
                THEN O.amount
                ELSE 0 
                END AS payment_amount
            FROM liabilities AS L
            LEFT JOIN charges AS C 
                ON L.id_charge = C.id_charge
            LEFT JOIN out_payments AS O 
                ON L.id_client = O.id_client 
                    AND L.due_date = O.payment_date
                    AND L.id_charge = O.id_charge
                    AND L.amount = O.amount
            WHERE L.id_client = client_id 
                AND L.due_date BETWEEN start_date AND end_date) 
            AS obligation_data);
    SET report = CONCAT(report, 'Detalle de Obligaciones y Pagos:\n', obligation_details, '\n');
##Saldo final
    SET final_balance = 
        initial_balance
        + 
        (SELECT COALESCE(SUM(amount), 0)
        FROM liabilities
        WHERE id_client = client_id 
            AND due_date BETWEEN start_date AND end_date)
        -
        (SELECT COALESCE(SUM(amount), 0)
        FROM in_payments
        WHERE id_client = client_id 
            AND receipt_date BETWEEN start_date AND end_date);
    SET report = CONCAT(report, 'Saldo Final: ', final_balance, '\n');
    RETURN report;
END //
DELIMITER ;

########### Calculadora de impuestos a pagar por cobro de honorarios + honorario neto a percibir.
DELIMITER //
CREATE FUNCTION net_fee_and_taxes(honorarios NUMERIC)
RETURNS TEXT
NO SQL
BEGIN
    DECLARE iva_21 NUMERIC;
    DECLARE iibb NUMERIC;
    DECLARE net_fee NUMERIC;
    DECLARE resultado TEXT;
    SET iva_21 = (honorarios / 1.21) * 0.21; ## Calcula el 21% de IVA
    SET iibb = (honorarios / 1.21) * 0.035; ##Calcula el 3.5% de IIBB
    SET net_fee = honorarios - iva_21 - iibb; ## Calcula honorarios netos
    SET resultado = CONCAT('IVA 21%: ', iva_21, '\n');
    SET resultado = CONCAT(resultado, 'IIBB 3.5%: ', iibb, '\n');
    SET resultado = CONCAT(resultado, 'Honorarios netos: ', net_fee, '\n');
    RETURN resultado;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE liabilities_alert()
BEGIN
    DECLARE vencimiento_limite DATE;
    SET vencimiento_limite = DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY); ##Intervalo de 7 días.
    SELECT
        C.client_name,
        A.agency_description,
        CH.charge_description,
        L.due_date,
        L.amount
    FROM liabilities AS L
    INNER JOIN clients AS C 
        ON L.id_client = C.id_client
    INNER JOIN charges AS CH 
        ON L.id_charge = CH.id_charge
    LEFT JOIN agencies AS A 
        ON CH.id_agency = A.id_agency
    WHERE L.due_date BETWEEN CURRENT_DATE AND vencimiento_limite
        AND C.id_client 
            IN
            (SELECT DISTINCT id_client 
            FROM outpayment_worklist); ## Verifica la existencia en outpayment_worklist.
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE interest_generation(IN tna NUMERIC)
BEGIN
    ##Fecha límite para determinar la falta de pago en los últimos 60 días
    DECLARE fecha_limite DATE;
    ##Tasa de interés anual convertida a tasa decimal (por ejemplo, 5% como 0.05)
    DECLARE tasa_decimal DECIMAL(8,4);
    ##Coeficiente de actualización de honorarios
    DECLARE coeficiente_intereses DECIMAL(8, 4);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Error encontrado. Rollback realizado.' AS message;
    END;
    START TRANSACTION;
    ##Seteo de variables
    SET fecha_limite = DATE_SUB(CURRENT_DATE, INTERVAL 60 DAY);
    SET tasa_decimal = tna / 100;
    SET coeficiente_intereses = tasa_decimal / 365 * 30;
    ##Insertar liabilities con id_charge = 14 (intereses por mora) para clientes con falta de pago
    INSERT INTO liabilities (due_date, id_client, id_charge, amount)
    SELECT DISTINCT
        CURRENT_DATE AS due_date,
        C.id_client,
        14 AS id_charge,
        ((SELECT SUM(L.amount) 
        FROM liabilities AS L 
        WHERE L.id_charge = 1 
            AND L.id_client = C.id_client) 
            - 
        (SELECT COALESCE(SUM(I.amount), 0)
        FROM in_payments AS I 
        WHERE I.id_client = C.id_client))
        * coeficiente_intereses AS amount 
    FROM clients AS C
    LEFT JOIN in_payments AS I 
        ON C.id_client = I.id_client
    LEFT JOIN clients_fees AS CF 
        ON C.id_client = CF.id_client
    LEFT JOIN clients_account_statement AS CAS
        ON C.id_client = C.id_client
    WHERE I.id_inpay IS NULL
        AND C.onboarding_date <= fecha_límite
        AND CAS.account_balance > 0; 
    COMMIT;
    SELECT 'Procedimiento completado exitosamente.' AS message;
END //
DELIMITER ;

DELIMITER //

CREATE PROCEDURE update_monthly_fees(IN interest_rate DECIMAL(5,2))
BEGIN
    DECLARE last_fee_due_date DATE;
    DECLARE new_fee_amount DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error en el procedimiento update_monthly_fees. Rollback realizado.';
    END;

    START TRANSACTION;

    SELECT MAX(due_date) INTO last_fee_due_date
    FROM liabilities
    WHERE id_charge = 1;

    INSERT INTO liabilities (due_date, id_client, id_charge, amount)
    SELECT DISTINCT 
        DATE_ADD(LAST_DAY(last_fee_due_date), INTERVAL 1 DAY) AS new_due_date,
        id_client,
        1 AS id_charge,
        (SELECT MAX(amount) 
         FROM liabilities 
         WHERE id_charge = 1 AND due_date = last_fee_due_date AND L.id_client = liabilities.id_client) * (1 + interest_rate) AS new_fee_amount
    FROM liabilities AS L
    WHERE id_charge = 1 AND due_date = last_fee_due_date;

    COMMIT;
    SELECT 'Procedimiento completado exitosamente.' AS message;
END //

DELIMITER ;

START TRANSACTION;

INSERT INTO business_types(business_type_description) VALUES
('Persona fisica'),
('SA'),
('SRL'),
('SH'),
('SAS'),
('SCS');
SAVEPOINT savepoint_before_industries;
INSERT INTO industries(industry_description) VALUES
('Agricultura'),
('Construccion'),
('Educacion'),
('Tecnologia de la Informacion'),
('Servicios Financieros'),
('Salud'),
('Manufactura'),
('Medios de Comunicacion'),
('Transporte y Logistica'),
('Turismo y Hospitalidad'),
('Comercio Minorista'),
('Energia'),
('Servicios Legales'),
('Alimentacion y Bebidas'),
('Arquitectura e Ingenieria'),
('Bienes Raices'),
('Entretenimiento'),
('Medio Ambiente y Sostenibilidad'),
('Telecomunicaciones'),
('Moda y Textiles'),
('Automocion'),
('Biotecnologia'),
('Agricultura de Precision'),
('Industria Aeroespacial'),
('Quimica y Farmaceutica'),
('Medios Digitales'),
('Ingenieria Civil'),
('Energias Renovables'),
('Servicios de Consultoria'),
('Investigacion y Desarrollo');
INSERT INTO tax_regimes(tax_regime_description) VALUES
('Regimen simplificado'),
('Regimen general'),
('Regimen de exportacion'),
('Exento'),
('Jubilado');
SAVEPOINT savepoint_before_clients;
INSERT INTO clients(client_name, cuit, id_business_type, id_industry, id_tax_regime, onboarding_date, is_current_client) VALUES
('Lopez Jumanji S.A.S.', 30724424878, 5, 1, 2, '2019-11-01', TRUE),
('Silvina Sanchez S.A.', 30749771605, 2, 15, 2, '2012-06-02', TRUE),
('Leticia De Rio', 27289061989, 1, 16, 2, '2010-02-21', TRUE),
('Cristian Vargas', 20389651001, 1, 7, 1, '2020-10-20', TRUE),
('Marcelo Freja', 20229753089, 1, 29, 1, '2022-05-23', TRUE),
('Valentin Natalio', 20338575902, 1, 29, 2, '2023-09-01', TRUE);
INSERT INTO agencies(agency_description) VALUES
('ECL'),
('AFIP'),
('SIRCREB'),
('SIRCUPA'),
('ARBA'),
('AGIP'),
('MUNICIPALIDAD');
INSERT INTO charges(charge_description, id_agency) VALUES
('Honorarios', 1),
('Monotributo', 2),
('IVA', 2),
('Impuesto a las Ganancias', 2),
('IIBB Convenio multilateral', 3),
('IIBB Buenos Aires', 5),
('Autónomos', 2),
('Tasa seguridad e higiene', 7),
('Aportes empleada doméstica', 2),
('F-931 Seguridad social', 2),
('F-931 Obra social', 2),
('F-931 A.R.T.', 2),
('F-931 Seguro de vida obligatorio', 2),
('Intereses por mora', 1);
SAVEPOINT savepoint_before_transactions;
INSERT INTO liabilities (due_date, id_client, id_charge, amount) VALUES
('2023-11-01', 1, 1, 40000),
('2023-11-01', 2, 1, 50000),
('2023-11-01', 3, 1, 25000),
('2023-11-01', 4, 1, 15000),
('2023-11-01', 5, 1, 15000),
('2023-11-20', 4, 2, 12776.61),
('2023-11-20', 5, 2, 15712.4),
('2023-11-17', 1, 3, 123000),
('2023-11-17', 2, 3, 220000),
('2023-11-17', 3, 3, 62000),
('2023-11-28', 1, 5, 17571.43),
('2023-11-28', 2, 5, 31428.57),
('2023-11-28', 3, 5, 8857.14),
('2023-11-28', 4, 5, 7800),
('2023-11-28', 5, 5, 6200),
('2023-11-18', 1, 7, 12000),
('2023-11-18', 2, 7, 15000),
('2023-11-07', 1, 10, 35000),
('2023-11-07', 1, 11, 12000),
('2023-11-07', 1, 12, 4000),
('2023-11-07', 1, 13, 600),
('2023-12-01', 1, 1, 48000),
('2023-11-01', 1, 1, 14200),
('2023-09-01', 6, 1, 10000),
('2023-10-01', 6, 1, 10000),
('2023-11-01', 6, 1, 10000),
('2023-12-01', 1, 1, 54000),
('2023-12-01', 2, 1, 67500),
('2023-12-01', 3, 1, 33750),
('2023-12-01', 4, 1, 20250),
('2023-12-01', 5, 1, 20250),
('2023-12-20', 4, 2, 17263.75),
('2023-12-20', 5, 2, 21206.74),
('2023-12-17', 1, 3, 165450),
('2023-12-17', 2, 3, 297000),
('2023-12-17', 3, 3, 83700),
('2023-12-28', 1, 5, 23693.71),
('2023-12-28', 2, 5, 42342.99),
('2023-12-28', 3, 5, 11959.99),
('2023-12-28', 4, 5, 10530),
('2023-12-28', 5, 5, 8370),
('2023-12-18', 1, 7, 16200),
('2023-12-18', 2, 7, 20250),
('2023-12-07', 1, 10, 47250),
('2023-12-07', 1, 11, 16200),
('2023-12-07', 1, 12, 5400),
('2023-12-07', 1, 13, 810),
('2023-12-01', 6, 1, 13500);
INSERT INTO in_payments(receipt_date, id_client, amount) VALUES
('2023-11-01', 1, 150000),
('2023-11-01', 2, 300000),
('2023-11-02', 3, 100000),
('2023-11-08', 4, 25000),
('2023-11-12', 5, 5000),
('2023-11-13', 1, 380000),
('2023-11-18', 4, 3000),
('2023-11-24', 5, 15000),
('2023-11-26', 2, 60000),
('2023-12-03', 1, 402500),
('2023-12-15', 2, 405000),
('2023-12-08', 3, 435000),
('2023-12-24', 4, 33750),
('2023-12-18', 5, 6750),
('2023-12-26', 1, 130000),
('2023-12-03', 4, 4050),
('2023-12-14', 5, 20250),
('2023-12-10', 2, 81000);
INSERT INTO out_payments(payment_date, id_client, id_charge, amount) VALUES
('2023-11-01', 1, 1, 40000),
('2023-11-01', 2, 1, 50000),
('2023-11-01', 3, 1, 25000),
('2023-11-01', 4, 1, 15000),
('2023-11-01', 5, 1, 15000),
('2023-11-20', 4, 2, 12776.61),
('2023-11-20', 5, 2, 15712.4),
('2023-11-17', 1, 3, 123000),
('2023-11-17', 2, 3, 220000),
('2023-11-17', 3, 3, 62000),
('2023-11-28', 1, 5, 17571.43),
('2023-11-28', 2, 5, 31428.57),
('2023-11-28', 3, 5, 8857.14),
('2023-11-28', 4, 5, 7800),
('2023-11-18', 1, 7, 12000),
('2023-11-18', 2, 7, 15000),
('2023-11-07', 1, 12, 4000),
('2023-11-07', 1, 13, 600),
('2023-12-01', 1, 1, 54000),
('2023-12-01', 2, 1, 67500),
('2023-12-01', 3, 1, 33750),
('2023-12-01', 4, 1, 20250),
('2023-12-01', 5, 1, 20250),
('2023-12-20', 4, 2, 17263.75),
('2023-12-20', 5, 2, 21206.74),
('2023-12-17', 1, 3, 83700),
('2023-12-17', 2, 3, 148500),
('2023-12-17', 3, 3, 41850),
('2023-12-28', 1, 5, 23769.99),
('2023-12-28', 2, 5, 42342.99),
('2023-12-28', 3, 5, 11959.99),
('2023-12-28', 4, 5, 10530),
('2023-12-18', 1, 7, 16200),
('2023-12-18', 2, 7, 20250),
('2023-12-07', 1, 12, 5400),
('2023-12-07', 1, 13, 810);


SELECT 'PROCESO EXITOSO!! Usar COMMIT; para confirmar inserción de datos. En caso de requerirlo, usar ROLLBACK; o ROLLBACK TO savepoint;' AS message;

COMMIT;