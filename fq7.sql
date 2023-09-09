-- その日のログインUUを、直近7日間中何日アクセスしていたか(fq7)に色分けする
-- 参照テーブルは下記１件。最低２カラムのログテーブルの想定
-- dataset.user_access  -> timestamp,user_id

CREATE TEMPORARY FUNCTION measure_from() AS (DATE("2022-02-01"));
CREATE TEMPORARY FUNCTION measure_to() AS (DATE("2022-03-31"));
CREATE TEMPORARY FUNCTION login_from() AS (DATE_SUB(measure_from(), INTERVAL 6 DAY));

WITH

-- ログインユーザーの抽出
login_user AS (
    SELECT DISTINCT --ログ重複の削除
        DATE(timestamp,'Asia/Tokyo') AS login_date,
        user_id
    FROM
        dataset.user_login
    WHERE
        -- FQ7を出力したい期間の6日前からのログインログを抽出する必要がある
        DATE(timestamp,'Asia/Tokyo') BETWEEN login_from() AND measure_to()
),

-- FQの算出
calc_fq  AS (
    SELECT DISTINCT
        login_date,
        user_id,
        COUNT(login_date) OVER (
            PARTITION BY user_id 
            ORDER BY UNIX_DATE(login_date) 
            RANGE BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS fq
    FROM
        login_user
)

SELECT
    login_date,
    fq,
    COUNT(user_id) AS uu
FROM
    calc_fq
WHERE
    login_date >= measure_from()
GROUP BY
    1,2
ORDER BY
    1,2
;