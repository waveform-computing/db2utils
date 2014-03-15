CREATE TABLE FOO (
    ID INTEGER NOT NULL,
    VALUE INTEGER NOT NULL
)!

CREATE TABLE BAR LIKE FOO!
ALTER TABLE BAR ADD CONSTRAINT PK PRIMARY KEY (ID)!

INSERT INTO FOO VALUES
    (1, 2),
    (2, 4),
    (3, 8),
    (4, 16),
    (5, 32)!

CALL AUTO_MERGE('FOO', 'BAR', 'PK')!
VALUES ASSERT_EQUALS(5, (SELECT COUNT(*) FROM (SELECT * FROM FOO INTERSECT SELECT * FROM BAR) AS T))!

INSERT INTO FOO VALUES
    (6, 64),
    (7, 128)!

CALL AUTO_MERGE('FOO', 'BAR')!
VALUES ASSERT_EQUALS(7, (SELECT COUNT(*) FROM (SELECT * FROM FOO INTERSECT SELECT * FROM BAR) AS T))!

DELETE FROM FOO WHERE ID IN (1, 2)!

CALL AUTO_DELETE('FOO', 'BAR')!
VALUES ASSERT_EQUALS(5, (SELECT COUNT(*) FROM (SELECT * FROM FOO INTERSECT SELECT * FROM BAR) AS T))!

DELETE FROM FOO!

CALL AUTO_DELETE('FOO', 'BAR', 'PK')!
VALUES ASSERT_EQUALS(0, (SELECT COUNT(*) FROM BAR))!

CREATE TABLE BAZ (
    COUNTRY CHAR(2) NOT NULL,
    ID INTEGER NOT NULL,
    GIVENNAME VARCHAR(100) NOT NULL,
    SURNAME VARCHAR(100) NOT NULL,
    AGE INTEGER DEFAULT 0 NOT NULL
)!

CREATE TABLE EMP (
    COUNTRY CHAR(2) NOT NULL,
    ID INTEGER NOT NULL,
    GIVENNAME VARCHAR(100) NOT NULL,
    SURNAME VARCHAR(100) NOT NULL,
    NAME GENERATED ALWAYS AS (GIVENNAME || ' ' || SURNAME),
    CONSTRAINT PK PRIMARY KEY (COUNTRY, ID)
)!

INSERT INTO BAZ VALUES
    ('GB', 1, 'Fred', 'Flintstone', 45),
    ('GB', 2, 'Barney', 'Rubble', 42),
    ('GB', 3, 'Wilma', 'Flintstone', 43),
    ('GB', 4, 'Betty', 'Rubble', 42)!

CALL AUTO_INSERT('BAZ', 'EMP')!
VALUES ASSERT_EQUALS(4, (SELECT COUNT(*) FROM (
        SELECT COUNTRY, ID, GIVENNAME, SURNAME FROM BAZ
        INTERSECT
        SELECT COUNTRY, ID, GIVENNAME, SURNAME FROM EMP
    ) AS T))!

INSERT INTO BAZ VALUES
    ('GB', 5, 'Pebbles', 'Flintstone', 2),
    ('GB', 6, 'Bamm-Bamm', 'Rubble', 3)!

CALL AUTO_MERGE('BAZ', 'EMP', 'PK')!
VALUES ASSERT_EQUALS(6, (SELECT COUNT(*) FROM (
        SELECT COUNTRY, ID, GIVENNAME, SURNAME FROM BAZ
        INTERSECT
        SELECT COUNTRY, ID, GIVENNAME, SURNAME FROM EMP
    ) AS T))!

DROP TABLE FOO!
DROP TABLE BAR!
DROP TABLE BAZ!
DROP TABLE EMP!

-- vim: set et sw=4 sts=4:
