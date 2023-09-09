-- 獲得したインストールユーザーの獲得n日後までの平均売上を、日単位で計算する(ROAS測定などで利用)
-- 参照テーブルは下記２件。最低２〜３カラムのログテーブルの想定
-- dataset.user_install -> timestamp,user_id
-- dataset.user_payment  -> timestamp,user_id,amount


CREATE TEMPORARY FUNCTION install_from() AS (DATE("2022-02-01"));
CREATE TEMPORARY FUNCTION install_to() AS (DATE("2022-04-30"));
CREATE TEMPORARY FUNCTION measure_to() AS (DATE_ADD(install_to(), INTERVAL 180 DAY));

WITH

-- インストールユーザーの抽出
new_user AS (
	SELECT DISTINCT --ログ重複の削除
		DATE(timestamp,'Asia/Tokyo') AS install_date,
		user_id
	FROM
		dataset.user_install
	WHERE
		DATE(timestamp,'Asia/Tokyo') BETWEEN install_from() AND install_to()
),

-- LTVの分母(日毎のインストールUU)を算出
calc_nuu_num AS (
	SELECT
		install_date,
		COUNT(user_id) AS install_uu
	FROM
		new_user
	GROUP BY
		1
),

-- ユーザーの日毎の売上を算出
user_pay AS (
	SELECT
		DATE(timestamp,'Asia/Tokyo') AS purchase_date,
		user_id,
    sum(amount) as purchase
	FROM
		dataset.user_payment
	WHERE
		DATE(timestamp,'Asia/Tokyo') BETWEEN install_from() AND measure_to()
	GROUP BY 1,2
),

-- インストール日＋180日の課金ログ
install_and_pay AS (
    SELECT
        new_user.install_date,
        user_pay.user_id,
        user_pay.purchase_date,
        user_pay.purchase
    FROM
        user_pay
        JOIN
        new_user
            USING(user_id)
),

-- ユーザー別のインストール後経過日毎の累計売上額を集計
user_pay_agg AS (
    SELECT
        install_and_pay.install_date,
        install_and_pay.user_id,
        elapsed_days,
        DATE_ADD(install_and_pay.install_date, INTERVAL elapsed_days DAY) AS mesuring_date,
        SUM(install_and_pay.purchase) AS purchase
    FROM
        install_and_pay,
        UNNEST([0,1,3,7,14,30,180]) elapsed_days -- 任意の経過日を設定する
    WHERE
        install_and_pay.purchase_date <= DATE_ADD(install_and_pay.install_date, INTERVAL elapsed_days DAY)
    GROUP BY
        1,2,3,4
),

-- インストール日別・経過日別の情報に集約
agg AS (
    SELECT
        install_date,
        mesuring_date,
        elapsed_days,
        COUNT(user_id) AS uu,
        SUM(purchase) AS purchase
    FROM
        user_pay_agg
    WHERE
        -- 締まっていないデータを排除する
        mesuring_date < CURRENT_DATE("Asia/Tokyo") 
    GROUP BY
        1,2,3
)

SELECT
    agg.install_date,
    calc_nuu_num.install_uu,
    agg.mesuring_date,
    agg.elapsed_days,
    agg.uu AS purchase_uu,
    agg.purchase AS purchase,
    agg.uu / calc_nuu_num.install_uu AS purchase_uu_rate,
    agg.purchase / agg.uu AS arppu,
    agg.purchase / calc_nuu_num.install_uu AS LTV
FROM
    agg
    JOIN
    calc_nuu_num
        USING(install_date)
ORDER BY
    1,3