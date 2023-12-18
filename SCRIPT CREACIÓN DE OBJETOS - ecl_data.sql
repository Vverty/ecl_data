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

CREATE PROCEDURE update_monthly_fees(IN interest_rate NUMERIC)
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
    WHERE id_charge = 1
    GROUP BY id_client;

    SET new_fee_amount = (SELECT amount FROM liabilities WHERE id_charge = 1 AND due_date = last_fee_due_date) * (1 + interest_rate);

    INSERT INTO liabilities (due_date, id_client, id_charge, amount)
    SELECT DATE_ADD(LAST_DAY(last_fee_due_date), INTERVAL 1 DAY), id_client, 1, new_fee_amount
    FROM liabilities
    WHERE id_charge = 1 AND due_date = last_fee_due_date;

    COMMIT;
    SELECT 'Procedimiento completado exitosamente.' AS message;
END //

DELIMITER ;