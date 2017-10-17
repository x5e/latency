DO
$body$
BEGIN
   IF NOT EXISTS (
      SELECT 
      FROM   pg_catalog.pg_user
      WHERE  usename = 'doorman') THEN
      CREATE USER doorman PASSWORD 'doorman';
   END IF;
END
$body$;
