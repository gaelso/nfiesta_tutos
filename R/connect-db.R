
# ---- packages ----
library(DBI)
library(RPostgres)
library(dplyr)

# ---- connection ----
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "nfiesta_lab",
  host     = "127.0.0.1",
  port     = 5432,
  user     = "vagrant",
  password = rstudioapi::askForPassword()
)

# quick sanity check
dbGetQuery(con, "SELECT current_database(), current_user;")

# ---- helper ----
show_n <- function(df, n = 20) {
  print(utils::head(df, n), row.names = FALSE)
  invisible(df)
}

# ---- 1) installed extensions ----
extensions <- dbGetQuery(con, "
  SELECT extname, extversion
  FROM pg_extension
  ORDER BY extname;
")
show_n(extensions, 50)

# ---- 2) all non-system schemas ----
schemas <- dbGetQuery(con, "
  SELECT schema_name
  FROM information_schema.schemata
  WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
  ORDER BY schema_name;
")
show_n(schemas, 100)

# ---- 3) all non-system tables ----
tables_all <- dbGetQuery(con, "
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_type = 'BASE TABLE'
    AND table_schema NOT IN ('pg_catalog', 'information_schema')
  ORDER BY table_schema, table_name;
")
show_n(tables_all, 200)

# ---- 4) only nfiesta-related tables ----
tables_nfiesta <- dbGetQuery(con, "
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_type = 'BASE TABLE'
    AND (
      table_schema ILIKE 'nfiesta%'
      OR table_name ILIKE '%nfiesta%'
      OR table_name ILIKE '%estimate%'
      OR table_name ILIKE '%model%'
      OR table_name ILIKE '%target%'
      OR table_name ILIKE '%plot%'
    )
  ORDER BY table_schema, table_name;
")
show_n(tables_nfiesta, 200)

# ---- 5) all non-system views ----
views_all <- dbGetQuery(con, "
  SELECT table_schema, table_name
  FROM information_schema.views
  WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  ORDER BY table_schema, table_name;
")
show_n(views_all, 200)

# ---- 6) all routines/functions in non-system schemas ----
# information_schema.routines is portable and easy to inspect
routines_all <- dbGetQuery(con, "
  SELECT routine_schema, routine_name, routine_type
  FROM information_schema.routines
  WHERE routine_schema NOT IN ('pg_catalog', 'information_schema')
  ORDER BY routine_schema, routine_name;
")
show_n(routines_all, 300)

# ---- 7) PostgreSQL-specific function inventory with arguments and return types ----
functions_pg <- dbGetQuery(con, "
  SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS args,
    pg_get_function_result(p.oid) AS return_type
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY n.nspname, p.proname;
")
show_n(functions_pg, 300)

# ---- 8) focus on nfiesta / htc / sdesign functions ----
functions_core <- dbGetQuery(con, "
  SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS args,
    pg_get_function_result(p.oid) AS return_type
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname ILIKE 'nfiesta%'
     OR n.nspname ILIKE '%sdesign%'
     OR n.nspname ILIKE 'htc%'
     OR p.proname ILIKE '%estimate%'
     OR p.proname ILIKE '%model%'
     OR p.proname ILIKE '%target%'
  ORDER BY n.nspname, p.proname;
")
show_n(functions_core, 300)

# ---- 9) table column dictionary for nfiesta-ish schemas ----
columns_core <- dbGetQuery(con, "
  SELECT
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    data_type
  FROM information_schema.columns
  WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
    AND (
      table_schema ILIKE 'nfiesta%'
      OR table_name ILIKE '%estimate%'
      OR table_name ILIKE '%model%'
      OR table_name ILIKE '%target%'
      OR table_name ILIKE '%plot%'
    )
  ORDER BY table_schema, table_name, ordinal_position;
")
show_n(columns_core, 300)

# ---- 10) candidate configuration tables ----
candidate_config_tables <- dbGetQuery(con, "
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_type = 'BASE TABLE'
    AND table_schema NOT IN ('pg_catalog', 'information_schema')
    AND (
      table_name ILIKE '%conf%'
      OR table_name ILIKE '%config%'
      OR table_name ILIKE '%estimate%'
      OR table_name ILIKE '%model%'
    )
  ORDER BY table_schema, table_name;
")
show_n(candidate_config_tables, 200)

# ---- 11) preview a known configuration table if it exists ----
has_total_estimate_conf <- dbGetQuery(con, "
  SELECT COUNT(*) AS n
  FROM information_schema.tables
  WHERE table_schema = 'nfiesta'
    AND table_name = 't_total_estimate_conf';
")$n[1] > 0

if (has_total_estimate_conf) {
  total_estimate_conf <- dbGetQuery(con, "
    SELECT *
    FROM nfiesta.t_total_estimate_conf
    LIMIT 20;
  ")
  show_n(total_estimate_conf, 20)
} else {
  message("Table nfiesta.t_total_estimate_conf not found in this database.")
}

# ---- 12) save inventories locally for inspection ----
write.csv(extensions, "extensions.csv", row.names = FALSE)
write.csv(schemas, "schemas.csv", row.names = FALSE)
write.csv(tables_all, "tables_all.csv", row.names = FALSE)
write.csv(tables_nfiesta, "tables_nfiesta.csv", row.names = FALSE)
write.csv(views_all, "views_all.csv", row.names = FALSE)
write.csv(routines_all, "routines_all.csv", row.names = FALSE)
write.csv(functions_pg, "functions_pg.csv", row.names = FALSE)
write.csv(functions_core, "functions_core.csv", row.names = FALSE)
write.csv(columns_core, "columns_core.csv", row.names = FALSE)
write.csv(candidate_config_tables, "candidate_config_tables.csv", row.names = FALSE)

# ---- 13) optional: disconnect ----
# dbDisconnect(con)




