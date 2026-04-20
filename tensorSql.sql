-- Tensor Algebra over MySQL
-- Rappresentazione di operazioni tensoriali come funzioni/procedure SQL

DROP TABLE IF EXISTS tensor_A;
DROP TABLE IF EXISTS tensor_B;
DROP TABLE IF EXISTS tensor_C;
DROP TABLE IF EXISTS tensor_D;
DROP TABLE IF EXISTS symmetric_tensor;

-- ========================================
-- 1. Tensori base (ordine 2)
-- ========================================

CREATE TABLE tensor_A (
    i INT NOT NULL,
    j INT NOT NULL,
    value DOUBLE NOT NULL,
    PRIMARY KEY (i, j)
);

CREATE TABLE tensor_B (
    j INT NOT NULL,
    k INT NOT NULL,
    value DOUBLE NOT NULL,
    PRIMARY KEY (j, k)
);

-- ========================================
-- 2. Tensore simmetrico
-- ========================================

CREATE TABLE symmetric_tensor (
    i INT NOT NULL,
    j INT NOT NULL,
    value DOUBLE NOT NULL,
    PRIMARY KEY (i, j),
    CHECK (i <= j)
);

-- ========================================
-- 3. Funzione: lettura componente tensor_A(i,j)
-- ========================================

DELIMITER //

CREATE FUNCTION get_tensor_A_component(
    p_i INT,
    p_j INT
)
RETURNS DOUBLE
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE result DOUBLE;

    SELECT value
    INTO result
    FROM tensor_A
    WHERE i = p_i
      AND j = p_j
    LIMIT 1;

    RETURN result;
END //

DELIMITER ;

-- Uso:
-- SELECT get_tensor_A_component(2,3);


-- ========================================
-- 4. Procedura: contrazione tensoriale
-- C(i,k) = SUM_j A(i,j) * B(j,k)
-- ========================================

DELIMITER //

CREATE PROCEDURE tensor_contract()
BEGIN
    DROP TABLE IF EXISTS tensor_C;

    CREATE TABLE tensor_C AS
    SELECT
        A.i,
        B.k,
        SUM(A.value * B.value) AS value
    FROM tensor_A A
    JOIN tensor_B B
        ON A.j = B.j
    GROUP BY
        A.i,
        B.k;
END //

DELIMITER ;

-- Uso:
-- CALL tensor_contract();


-- ========================================
-- 5. Procedura: prodotto tensoriale
-- D(i,j,k,l) = A(i,j) ⊗ B(k,l)
-- Nota: qui B viene interpretato come (k,l)
-- ========================================

DELIMITER //

CREATE PROCEDURE tensor_product()
BEGIN
    DROP TABLE IF EXISTS tensor_D;

    CREATE TABLE tensor_D AS
    SELECT
        A.i,
        A.j,
        B.j AS k,
        B.k AS l,
        A.value * B.value AS value
    FROM tensor_A A
    CROSS JOIN tensor_B B;
END //

DELIMITER ;

-- Uso:
-- CALL tensor_product();


-- ========================================
-- 6. Procedura: contrazione parziale
-- fissando j = fixed_j
-- ========================================

DELIMITER //

CREATE PROCEDURE partial_contract(
    IN fixed_j INT
)
BEGIN
    SELECT
        A.i,
        B.k,
        SUM(A.value * B.value) AS value
    FROM tensor_A A
    JOIN tensor_B B
        ON A.j = B.j
    WHERE A.j = fixed_j
    GROUP BY
        A.i,
        B.k;
END //

DELIMITER ;

-- Uso:
-- CALL partial_contract(2);


-- ========================================
-- 7. Procedura generica: mini tensor engine
-- ========================================

DELIMITER //

CREATE PROCEDURE tensor_engine(
    IN operation_type VARCHAR(50)
)
BEGIN
    IF operation_type = 'contract' THEN
        CALL tensor_contract();

    ELSEIF operation_type = 'product' THEN
        CALL tensor_product();

    ELSE
        SELECT 'Operazione non supportata' AS message;
    END IF;
END //

DELIMITER ;

-- Uso:
-- CALL tensor_engine('contract');
-- CALL tensor_engine('product');


-- ========================================
-- 8. Esempi di inserimento dati
-- ========================================

INSERT INTO tensor_A (i, j, value) VALUES
(1, 1, 2.0),
(1, 2, 3.0),
(2, 1, 4.0),
(2, 2, 5.0);

INSERT INTO tensor_B (j, k, value) VALUES
(1, 1, 10.0),
(1, 2, 20.0),
(2, 1, 30.0),
(2, 2, 40.0);

-- Esecuzione esempio:
-- CALL tensor_contract();
-- SELECT * FROM tensor_C;
