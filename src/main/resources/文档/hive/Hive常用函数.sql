
�������ں���
unix_timestamp:���ص�ǰ��ָ��ʱ���ʱ���	        select unix_timestamp();  select unix_timestamp('2008-08-08 08:08:08'); 
from_unixtime����ʱ���תΪ���ڸ�ʽ                 select from_unixtime(1218182888);
current_date����ǰ����                  select current_date();
current_timestamp����ǰ�����ڼ�ʱ��     select current_timestamp();
to_date����ȡ���ڲ���                   select to_date('2008-08-08 08:08:08');   select to_date(current_timestamp());
year����ȡ��                            select year(current_timestamp());
month����ȡ��                           select month(current_timestamp());
day����ȡ��                             select DAY(current_timestamp());
hour����ȡʱ                            select HOUR(current_timestamp());
minute����ȡ��                          select minute(current_timestamp());
second����ȡ��                          select SECOND(current_timestamp());
weekofyear����ǰʱ����һ���еĵڼ���    select weekofyear(current_timestamp());  select weekofyear('2020-01-08');
dayofmonth����ǰʱ����һ�����еĵڼ���  select dayofmonth(current_timestamp());  select dayofmonth('2020-01-08');
months_between�� �������ڼ���·�       select months_between('2020-07-29','2020-06-28');
add_months�����ڼӼ���                  select add_months('2020-06-28',1);
datediff������������������            select datediff('2019-03-01','2019-02-01');   select datediff('2020-03-01','2020-02-01');
date_add�����ڼ�����                    select date_add('2019-02-28',1);   select date_add('2020-02-28',1);
date_sub�����ڼ�����                    select date_sub('2019-03-01',1);   select date_sub('2020-03-01',1);
last_day�����ڵĵ��µ����һ��          select last_day('2020-02-28');   select last_day('2019-02-28');
date_format() ����ʽ������   ���ڸ�ʽ��'yyyy-MM-dd hh:mm:ss'   select date_format('2008-08-08 08:08:08','yyyy-MM-dd hh:mm:ss');  

����ȡ������
round�� ��������     select round(4.5);     
ceil��  ����ȡ��     select ceil(4.5);
floor�� ����ȡ��     select floor(4.5);

�����ַ�����������
upper�� ת��д         select upper('abcDEFg');
lower�� תСд         select lower('abcDEFg');
length�� ����          select length('abcDEFg');
trim��  ǰ��ȥ�ո�     select length('   abcDEFg    ');  select length(trim('   abcDEFg    '));
lpad�� �����룬��ָ������   select lpad('abc',11,'*');
rpad��  ���Ҳ��룬��ָ������  select rpad('abc',11,'*');  
substring: �����ַ���         select substring('abcdefg',1,3);     select rpad(substring('13843838438',1,3),11,'*');
regexp_replace�� SELECT regexp_replace('100-200', '(\\d+)', 'num');   select regexp_replace('abc d e f',' ','');
	ʹ��������ʽƥ��Ŀ���ַ�����ƥ��ɹ����滻��

���ϲ���
size�� ������Ԫ�صĸ���
map_keys�� ����map�е�key
map_values: ����map�е�value         select size(friends),map_keys(children),map_values(children) from person;
array_contains: �ж�array���Ƿ����ĳ��Ԫ��     select array_contains(friends,'lili') from person;
sort_array�� ��array�е�Ԫ������         select sort_array(split('1,3,4,5,2,6,9',','));   
                                         select sort_array(split('a,d,g,b,c,f,e',','));


