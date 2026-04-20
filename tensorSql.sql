-- Pulizia schema
DROP TABLE IF EXISTS tensor_A;
DROP TABLE IF EXISTS tensor_B;
DROP TABLE IF EXISTS tensor_C;
DROP TABLE IF EXISTS tensor_D;
DROP TABLE IF EXISTS symmetric_tensor;
DROP TABLE IF EXISTS tensor_sum;
-- Tensori di ordine 2 (Matrici Sparse)
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
-- Tensore Simmetrico con vincolo di struttura
CREATE TABLE symmetric_tensor (
i INT NOT NULL,
j INT NOT NULL,
value DOUBLE NOT NULL,
PRIMARY KEY (i, j),
CHECK (i <= j)
);

2. Funzioni di Accesso Ottimizzate

DELIMITER //
-- Lettura componente con gestione simmetria automatica
CREATE FUNCTION get_symmetric_component(p_i INT, p_j INT)
RETURNS DOUBLE DETERMINISTIC READS SQL DATA

BEGIN
DECLARE val DOUBLE;
-- Normalizzazione indici: garantisce i <= j
IF p_i > p_j THEN
SELECT value INTO val FROM symmetric_tensor WHERE i = p_j AND j = p_i;
ELSE
SELECT value INTO val FROM symmetric_tensor WHERE i = p_i AND j = p_j;
END IF;
RETURN IFNULL(val, 0.0);
END //
DELIMITER ;

3. Motore di Calcolo (Procedure)

DELIMITER //
-- Contrazione Tensoriale: C(i,k) = SUM_j A(i,j) * B(j,k)
CREATE PROCEDURE tensor_contract()
BEGIN
DROP TABLE IF EXISTS tensor_C;
CREATE TABLE tensor_C AS
SELECT A.i, B.k, SUM(A.value * B.value) AS value
FROM tensor_A A
JOIN tensor_B B ON A.j = B.j
GROUP BY A.i, B.k;
END //
-- Prodotto Tensoriale (Esterno): D(i,j,k,l) = A(i,j) ⊗ B(k,l)
CREATE PROCEDURE tensor_product()
BEGIN
DROP TABLE IF EXISTS tensor_D;
CREATE TABLE tensor_D AS
SELECT A.i, A.j, B.j AS k, B.k AS l, A.value * B.value AS value
FROM tensor_A A
CROSS JOIN tensor_B B;
END //
-- Addizione Tensoriale (Element-wise): S = A + B
CREATE PROCEDURE tensor_add()
BEGIN
DROP TABLE IF EXISTS tensor_sum;
CREATE TABLE tensor_sum AS
SELECT i, j, SUM(value) as value
FROM (
SELECT i, j, value FROM tensor_A
UNION ALL
SELECT j AS i, k AS j, value FROM tensor_B
) AS combined
GROUP BY i, j;
END //
DELIMITER ;

4. Esempio di Utilizzo

-- Inserimento dati di test
INSERT INTO tensor_A (i, j, value) VALUES (1,1,2), (1,2,3), (2,1,4), (2,2,5);
INSERT INTO tensor_B (j, k, value) VALUES (1,1,10), (1,2,20), (2,1,30), (2,2,40);
-- Esecuzione Calcoli
CALL tensor_contract();
CALL tensor_add();


--created by Giuseppe D'Ambrosio
SELECT * FROM tensor_C; -- Risultato contrazione
