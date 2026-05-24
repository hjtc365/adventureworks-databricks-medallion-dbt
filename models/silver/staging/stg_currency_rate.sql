{{ config(materialized="view") }}

with src as (select * from {{ source("sales", "CurrencyRate") }})

select
    cast(currencyrateid as int) as currency_rate_bk,
    cast(currencyratedate as timestamp) as currency_rate_date,
    fromcurrencycode as from_currency_code,
    tocurrencycode as to_currency_code,
    cast(averagerate as decimal(19, 4)) as average_rate,
    cast(endofdayrate as decimal(19, 4)) as end_of_day_rate,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
