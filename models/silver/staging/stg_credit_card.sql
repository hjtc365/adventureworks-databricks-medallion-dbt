{{ config(materialized="view") }}

with src as (select * from {{ source("sales", "CreditCard") }})

select
    cast(creditcardid as int) as credit_card_bk,
    cardtype as card_type,
    -- mask all but last 4 digits at minimum
    concat(
        repeat('X', greatest(length(cardnumber) - 4, 0)), right(cardnumber, 4)
    ) as card_number_masked,
    cast(expmonth as int) as exp_month,
    cast(expyear as int) as exp_year,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
