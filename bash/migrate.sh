#!/usr/bin/env bash
set -e
cd $(dirname $0)
psql -v ON_ERROR_STOP=1 <<<'select 1;'
for FN in ../migrations/*.sql; do
    echo ${FN}
    cat ${FN} | psql -v ON_ERROR_STOP=1
done
