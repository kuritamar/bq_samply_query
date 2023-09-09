-- 新規インストールユーザーの日別・日毎のアクセス継続率を算出する(マーケティングの効果測定などでの利用を想定)
-- 参照テーブルは下記２件。最低２カラムのログテーブルの想定
-- dataset.user_install -> timestamp,user_id
-- dataset.user_access  -> timestamp,user_id

CREATE TEMPORARY FUNCTION date_from() AS (DATE("2023-01-01"));
CREATE TEMPORARY FUNCTION date_to() AS (DATE("2023-03-31"));

WITH

-- インストールユーザーの抽出
new_user AS (
	SELECT DISTINCT --ログ重複の削除
		DATE(timestamp,'Asia/Tokyo') AS install_date,
		user_id
	FROM
		dataset.user_install
	WHERE
		DATE(timestamp,'Asia/Tokyo') BETWEEN date_from() AND date_to()
),

-- 継続率の分母(日毎のインストールUU)を算出
calc_nuu_num AS (
	SELECT
		install_date,
		COUNT(user_id) AS install_uu
	FROM
		new_user
	GROUP BY
		1
),

-- ログインユーザーの抽出
login_user AS (
	SELECT DISTINCT --ログ重複の削除
		DATE(timestamp,'Asia/Tokyo') AS login_date,
		user_id
	FROM
		dataset.user_login
	WHERE
		DATE(timestamp,'Asia/Tokyo') BETWEEN date_from() AND date_to()
),

-- インストールログとログインログを結合

base_table AS (
	SELECT
		install_date,
		login_date,
		user_id
	FROM
		login_user
		JOIN
		new_user
			USING(user_id)
),

-- 継続UUの算出
calc_return_uu AS (
  SELECT
		install_date,
		login_date,
		DATE_DIFF(login_date, install_date, DAY) AS days_after,
		COUNT(user_id) AS login_uu
	FROM
		base_table
	GROUP BY
		1,2,3
)

SELECT
	calc_return_uu.install_date,
	calc_nuu_num.install_uu,
	calc_return_uu.login_date,
	calc_return_uu.days_after,
	calc_return_uu.login_uu,
	calc_return_uu.login_uu / calc_nuu_num.install_uu AS return_rate 
FROM
  calc_return_uu
  JOIN
  calc_nuu_num
    USING(install_date)
WHERE
	days_after IN (0,1,3,5,7,14,30) --出力したい任意の経過日を指定する
;