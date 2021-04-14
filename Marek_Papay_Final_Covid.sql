CREATE TABLE t_Marek_Papay_projekt_SQL_final (
	Date date NOT NULL,
	Country varchar(255) NOT NULL,
	PRIMARY KEY (Country, Date)
	);

/* creating data for date and country as primary keys*/	
INSERT INTO t_Marek_Papay_projekt_SQL_final (date, country)
select date, Country 
from covid19_basic;

/* creating columns for confirmed, covid tests and population*/	
ALTER TABLE t_Marek_Papay_projekt_SQL_final ADD COLUMN Confirmed INT;
ALTER TABLE t_Marek_Papay_projekt_SQL_final ADD COLUMN Covid_Tests INT;
ALTER TABLE t_Marek_Papay_projekt_SQL_final ADD COLUMN Population INT;

/* update main table for confirmed cases*/	
UPDATE t_Marek_Papay_projekt_SQL_final mp
INNER JOIN covid19_basic_differences cbd 
	ON  mp.date = cbd.date
	and mp.country = cbd.country
		SET mp.Confirmed = cbd.Confirmed;

/* update main table for covid tests*/	
UPDATE t_Marek_Papay_projekt_SQL_final mp
INNER JOIN covid19_tests ct
	ON  mp.date = ct.date
	and mp.country = ct.country
		SET mp.Covid_Tests = ct.tests_performed;

/* update main table for population*/	
UPDATE t_Marek_Papay_projekt_SQL_final mp
INNER JOIN countries c
	on mp.country = c.country
		SET mp.Population = c.population;



/* creating a table for 0/1 weekend - first task*/
create table papay_weekday as
select *, case when weekday(date) in (5,6) then 1 else 0 end as week
FROM covid19_basic cb; 

/* creating a table seperate month,day - second task*/
create table day_month_papay as
select date, month(date) as month_day, day(date) as day_date
from covid19_basic cb;
/* creating a table with seasons - second task*/
create table seasons as
select DISTINCT date, month_day, day_date,
	   case
	   		when month_day >= 12 and day_date >= 21 then 0
	   		when month_day >= 9 and day_date >= 23 then 3
	   		when month_day >= 10 then 3
	   		when month_day >= 6 and day_date >= 21 then 2
	   		when month_day >= 7 then 2
	   		when month_day >= 3 and day_date >= 20 then 1
	   		when month_day >= 4 then 1
	   		else 0
	   	end as seasons
from day_month_papay dmp;

/* deleting index as I had to copy tables from the other database*/
alter table t_Marek_Papay_projekt_SQL_final
drop column `index`;

/* integrating dates to table*/
create table integration_date_to_final as
select  tmppsf.*, s.seasons, pw.week
from 	(select *
		 from t_Marek_Papay_projekt_SQL_final) tmppsf
		 join
		 (select date, seasons
		  from seasons ) s
		  on tmppsf.date = s.date
		  join
		 (select distinct date, week
		  from papay_weekday ) pw
		  on tmppsf.date = pw.date
		 order by tmppsf.country;
		

/* creating a table with density, GDP per person, gini cof. and children mortality - third, fourth, fifth, sixth task*/
create table countries_to_finale_GDP_gini_mor as
select tmppsf.*, round(c.population_density,2) as population_density, e.GDP/c.population as GDP_per_person, 
	   e.gini as gini_coef, e.mortaliy_under5 as children_mortality, c.median_age_2018 as med_age_2018
from t_Marek_Papay_projekt_SQL_final tmppsf
	join countries c
	on c.country = tmppsf.Country
	join economies e
	on e.country = tmppsf.country
	and e.population = tmppsf.Population;

/* integrating integration_date_to_final to gini, gdp and child. mortality*/
create table integration_date_to_final_gini_GDP_Mortal as
select idtf.*, ctfggm.population_density, ctfggm.GDP_per_person, ctfggm.gini_coef, ctfggm.children_mortality, ctfggm.med_age_2018
	from integration_date_to_final idtf 
	join countries_to_finale_gdp_gini_mor ctfggm 
	on idtf.date = ctfggm.date
	and idtf.Country = ctfggm.Country;


/* creating a table with seasons - religions - eighth task*/
create table pop_religion_per_country as
select r1.year ,r1.country, r1.religion,
	   round((r1.population/r2.sum_population)*100,2) as share_pop_per_country
	from (
		 select year ,country, religion, population 
		 from religions
		 where year = 2020
		 ) r1
	join (
		 select year, country, religion, population, sum(population) as sum_population
		 from religions
		 where year = 2020
		 group by country
		 ) r2
	on	r1.country = r2.country
	and r2.sum_population > 0
	and r2.sum_population is not null;

/* creating a table with seasons - religions - nineth task*/
create table life_expectyncy_diff as
select le.country, round(le2.life_expectancy - le.life_expectancy, 2) as life_expectancy_diff
from 
	(
	select *
	from life_expectancy
	where year = 1965
	) le
	join 
	(select *
	 from life_expectancy
	 where year = 2015) le2
	on le.country = le2.country;

/* religion to columns*/
create table distinct_religion
select distinct 
		country,
		case when religion = 'Christianity' then share_pop_per_country end Christianity,
		case when religion = 'Islam' then share_pop_per_country end Islam,
		case when religion = 'Hinduism' then share_pop_per_country end Hinduism,
		case when religion = 'Judaism' then share_pop_per_country end Judaism,
		case when religion = 'Unaffiliated Religions' then share_pop_per_country end Unaffiliated_Religions
from pop_religion_per_country;

/* null deleting*/
create table null_religion as 
select chr.country, chr.christianity, isl.islam, hind.hinduism, jud.judaism
from (select country, christianity
	  from distinct_religion
	  where christianity is not null and country <> 'All countries') as chr
join (select country, islam
	  from distinct_religion
	  where islam is not null) as isl
	  on chr.country = isl.country
join (select country, Hinduism
	  from distinct_religion
	  where Hinduism is not null) as hind
	  on chr.country = hind.country
join (select country, Judaism
	  from distinct_religion
	  where Judaism is not null) as jud
	  on chr.country = jud.country;

	 
/* creating a table with weather altogether - tenth,eleventh,twelth task*/
create table weather_complete_papay as
select w.date as date, avg(w1.temp) as avg_temperature ,count(w2.rain) as number_of_raining_hours, max(w.wind) as max_wind
	from (select date, wind, hour, rain
		  from weather) w
	join (select date, hour, temp
		  from weather
		  where hour >= 6 and hour <= 21) w1
	on w.date = w1.date
	join  (select date, rain
		  from weather
		  where rain <> 0 and rain is not null) w2
	on w.date = w2.date
	group by date;
	 
/* creating table and putting altogether all before joing with the weather*/
create table final_table_before_weather as
select  ctfggm.*, nr.christianity, nr.islam, nr.hinduism, nr.judaism, led.life_expectancy_diff
from 	(select *
		 from integration_date_to_final_gini_GDP_Mortal) ctfggm
		 join
		 (select *
		  from null_religion) nr
		  on ctfggm.country = nr.country
		 join
		 (select *
		  from life_expectyncy_diff) led
		  on led.country = ctfggm.country;


/* creating table and joing with the weather*/
create table marek_papay_final_table as
select ftbw.*, wcp.avg_temperature, wcp.number_of_raining_hours, wcp.max_wind 
	from final_table_before_weather ftbw
	join weather_complete_papay wcp
	on ftbw.date = wcp.`date`;