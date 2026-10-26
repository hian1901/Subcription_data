select * from subscriptions_raw;

-- create a backup table
create table subcription_raw_duplicate
like subscriptions_raw;

insert subcription_raw_duplicate
select * 
from subscriptions_raw;

select *
from subcription_raw_duplicate;

-- check a missing value
select
	count(*) as total_rows,
	sum(coalesce(trim(customer_email),'') = '') as missing_email,
	sum(coalesce(trim(country),'')= '') as missing_country,
	sum(coalesce(trim(start_date),'')= '')  as missing_start_date,
	sum(coalesce(trim(end_date),'')= '') as missing_end_date,
	sum(coalesce(trim(payment_method),'')= '')  as missing_payment_method
from subcription_raw_duplicate;
-- validate field
select 
payment_method,
count(*) as total
from  subcription_raw_duplicate
group by payment_method
order by total desc;
 
select 
payment_method,
case 
    when payment_method is null or payment_method in ('','N/A') then 'unknown'
    else payment_method
end as payment_method_cleaned
from  subcription_raw_duplicate;
-- update data
update subcription_raw_duplicate
set payment_method = 'Unknown'
where payment_method is null or payment_method in ('','N/A');

update subcription_raw_duplicate
set country = case
when country  in ('UK','U.K.') then 'United kingdom'
when country = 'Ie' then 'Ireland'
when country = 'De' then 'Germany'
when country = 'It' then 'Italy'
else country
end ;

-- Using subqueries instead of INITCAP
update subcription_raw_duplicate
set `status` = trim(concat(upper(substring(`status`,1,1)),lower(substring(`status`,2)))) ,
plan =  trim(concat(upper(substring(plan,1,1)),lower(substring(plan,2)))),
country =  trim(concat(upper(substring(country,1,1)),lower(substring(country,2))));


-- modify date 
select start_date,
case 
when start_date like '____-%' then str_to_Date(start_date,'%Y-%m-%d')
when start_date like '____/%' then str_to_Date(start_date,'%Y/%m/%d')
when start_date like '__-%' then str_to_Date(start_date,'%d-%m-%Y')
when start_date like '__/%' then str_to_Date(start_date,'%d/%m/%Y')
else null
end as start_date_clean
from subcription_raw_duplicate;

update subcription_raw_duplicate
set start_date = case
when start_date like '____-%' then str_to_Date(start_date,'%Y-%m-%d')
when start_date like '____/%' then str_to_Date(start_date,'%Y/%m/%d')
when start_date like '__-%' then str_to_Date(start_date,'%d-%m-%Y')
when start_date like '__/%' then str_to_Date(start_date,'%d/%m/%Y')
else null
end, 
end_date = case
when end_date like '____-%' then str_to_Date(end_date,'%Y-%m-%d')
when end_date like '____/%' then str_to_Date(end_date,'%Y/%m/%d')
when end_date like '__-%' then str_to_Date(end_date,'%d-%m-%Y')
when end_date like '__/%' then str_to_Date(end_date,'%d/%m/%Y')
else null
end;


update subcription_raw_duplicate
set monthly_price = abs(monthly_price);
update subcription_raw_duplicate
set monthly_price = monthly_price / 100 
where monthly_price > 100;

-- delete duplicate
with duplicate_data as(
select 
subscription_id,
row_number() over(partition by subscription_id,customer_id,customer_email,country,plan,monthly_price,`status`) as rn
from subcription_raw_duplicate
) 
select *
from duplicate_data
where rn >1;

CREATE TABLE `subcription_raw_duplicate2` (
  `subscription_id` text,
  `customer_id` text,
  `customer_email` text,
  `country` text,
  `plan` text,
  `monthly_price` double DEFAULT NULL,
  `status` text,
  `start_date` text,
  `end_date` text,
  `payment_method` text,
  `updated_at` text,
  `internal_notes` text,
  `rn` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

insert subcription_raw_duplicate2
select *,
row_number() over(partition by subscription_id,customer_id,customer_email,country,plan,monthly_price,`status`) as rn
from subcription_raw_duplicate;

delete 
from subcription_raw_duplicate2
where rn > 1;

alter table subcription_raw_duplicate2
drop column rn;
-- flag_data
select 
case
when lower(`status`) like '%active%' and end_date is not null then 'active wth end date'
when lower(`status`) like '%cancelled%' and end_date is null then 'cancelled wth out end date'
when lower(plan) not like '%free%' and monthly_price = 0  then 'paid plan with 0'
else 'ok'
end as quality_flag
from subcription_raw_duplicate2;

alter table subcription_raw_duplicate2
add column quality_flag Text;

update subcription_raw_duplicate2
set quality_flag= case
when lower(`status`) like '%active%' and end_date is not null then 'active wth end date'
when lower(`status`) like '%cancelled%' and end_date is null then 'cancelled wth out end date'
when lower(plan) not like '%free%' and monthly_price = 0  then 'paid plan with 0'
else 'ok'
end;
