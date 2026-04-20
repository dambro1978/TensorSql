-- TensorSQL Engine
-- Versione migliorata e normalizzata
-- Created by Giuseppe D'Ambrosio
-- ========================================
-- 1. Pulizia schema
-- ========================================

DROP TABLE IF EXISTS tensor_A;
DROP TABLE IF EXISTS tensor_B;
DROP TABLE IF EXISTS tensor_C;
DROP TABLE IF EXISTS tensor_D;
DROP TABLE IF EXISTS symmetric_tensor;
DROP TABLE IF EXISTS tensor_sum;


-- ========================================
-- 2. Tensori base (ordine 2 / matrici sparse)
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
-- 3. Tensore simmetrico
-- salva solo componenti con i <= j
-- ========================================

CREATE TABLE symmetric_tensor (
    i INT NOT NULL,
    j INT NOT NULL,
    value DOUBLE NOT NULL,
    PRIMARY KEY (i, j),
    CHECK (i <= j)
);


-- ========================================
-- 4. Funzione: accesso simmetrico automatico
-- get_symmetric_component(i,j)
-- ========================================

DELIMITER //

CREATE FUNCTION get_symmetric_component(
    p_i INT,
    p_j INT
)
RETURNS DOUBLE
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE val DOUBLE DEFAULT 0.0;

    IF p_i > p_j THEN
        SELECT value
        INTO val
        FROM symmetric_tensor
        WHERE i = p_j
          AND j = p_i
        LIMIT 1;
    ELSE
        SELECT value
        INTO val
        FROM symmetric_tensor
        WHERE i = p_i
          AND j = p_j
        LIMIT 1;
    END IF;

    RETURN IFNULL(val, 0.0);
END //

DELIMITER ;


-- ========================================
-- 5. Contrazione tensoriale
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


-- ========================================
-- 6. Prodotto tensoriale
-- D(i,j,k,l) = A(i,j) ⊗ B(k,l)
-- ========================================

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


-- ========================================
-- 7. Addizione tensoriale
-- S = A + B
-- (normalizzazione struttura)
-- ========================================

CREATE PROCEDURE tensor_add()
BEGIN
    DROP TABLE IF EXISTS tensor_sum;

    CREATE TABLE tensor_sum AS
    SELECT
        i,
        j,
        SUM(value) AS value
    FROM (
        SELECT
            i,
            j,
            value
        FROM tensor_A

        UNION ALL

        SELECT
            j AS i,
            k AS j,
            value
        FROM tensor_B
    ) AS combined
    GROUP BY
        i,
        j;
END //


-- ========================================
-- 8. Mini Tensor Engine
-- ========================================

CREATE PROCEDURE tensor_engine(
    IN operation_type VARCHAR(50)
)
BEGIN
    IF operation_type = 'contract' THEN
        CALL tensor_contract();

    ELSEIF operation_type = 'product' THEN
        CALL tensor_product();

    ELSEIF operation_type = 'add' THEN
        CALL tensor_add();

    ELSE
        SELECT 'Operazione non supportata' AS message;
    END IF;
END //

DELIMITER ;


-- ========================================
-- 9. Dati di test
-- ========================================

INSERT INTO tensor_A (i, j, value) VALUES
(1,1,2),
(1,2,3),
(2,1,4),
(2,2,5);

INSERT INTO tensor_B (j, k, value) VALUES
(1,1,10),
(1,2,20),
(2,1,30),
(2,2,40);


-- ========================================
-- 10. Einstein Notation Parser (versione iniziale)
-- uso:
-- CALL einstein('C(i,k)=A(i,j)*B(j,k)');
-- ========================================

DELIMITER //

CREATE PROCEDURE einstein(
    IN expr TEXT
)
BEGIN
    DECLARE sql_text TEXT;

    IF expr = 'C(i,k)=A(i,j)*B(j,k)' THEN

        SET sql_text = '
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
                B.k
        ';

        SET @sql = sql_text;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    ELSEIF expr = 'D(i,j,k,l)=A(i,j)*B(k,l)' THEN

        SET sql_text = '
            DROP TABLE IF EXISTS tensor_D;

            CREATE TABLE tensor_D AS
            SELECT
                A.i,
                A.j,
                B.j AS k,
                B.k AS l,
                A.value * B.value AS value
            FROM tensor_A A
            CROSS JOIN tensor_B B
        ';

        SET @sql = sql_text;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    ELSEIF expr = 'S(i,j)=A(i,j)+B(i,j)' THEN

        CALL tensor_add();

    ELSE
        SELECT 'Espressione Einstein non supportata' AS message;
    END IF;
END //

DELIMITER ;


-- ========================================
-- 11. Esempi di utilizzo
-- ========================================

-- CALL tensor_contract();
-- SELECT * FROM tensor_C;

-- CALL tensor_product();
-- SELECT * FROM tensor_D;

-- CALL tensor_add();
-- SELECT * FROM tensor_sum;

-- CALL tensor_engine('contract');
-- CALL tensor_engine('product');
-- CALL tensor_engine('add');

-- SELECT get_symmetric_component(3,2);
