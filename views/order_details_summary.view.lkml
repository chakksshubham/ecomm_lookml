#this is a native persistent derived table taken from explore of already available stuff
#persistent derived tables are written back into the database to prevent the sql based derived tables to write run sql query again and again that explore is rum
#persistent derived tables are usually used for complex queries which are costly to run or are used by many applications or users at a single time.
#a pdt can be defined by using any of the following 3 triggers
#1. Datagroup
#2. sql_trigger_value
#3. persist_for 

# data group:This is a centralised method for caching where this is defined in the model file
# this usually is a sql query which returns a single value and which is compared against the current values and when it doesnt match with current data the data in looker is updated 
# example 
# view: customer_order_summary {
#   derived_table: {
#     explore_source: orders {
#       ...
#     }
#     datagroup_trigger: orders_datagroup
#     indexes: ["customer_id", "first_order"]
#   }
# }

#sql_trigger_value: similar to datagroup in which a sql query read to db is used to update the table in looker but this is defined per table basis 
# example
# view: customer_order_facts{
#     derived_table:{
#         sql: select
#                 c.customer_id,
#                 min(o.order_date) over (partition by c.customer_id) as first_order_date,
#                 max(o.order_date) over (partition by c.customer_id) as most_recent_order_date,
#                 count(o.order_id) over (partition by c.customer_id) as lifetime_orders,
#                 sum(o.order_value) over (partition by c.customer_id) as lifetime_value,
#                 rank() over( partition by c.customer_id, order by o.order_date asc) as order_sequence,
#                 o.order_id
#                 from warehouse.customer c LEFT JOIN warehouse.order o ON c.customer_id = o.customer_id;;
#          sql_trigger_value: SELECT max(updated_time) ;;       
#                 }
#                 }

#persist_for: it doesnt depend on the db changes for the refreshing of the pdts rather automatically refreshes after a certain defined time
#example:view: customer {
  # sql_table_name: warehouse.customer
#   derived_table: {
#     sql: SELECT * FROM warehouse.customer ;;
#     persist_for: "8 hours"
#   }
# }
view: order_details_summary {
    derived_table: {
      explore_source: order_items {
        column: order_id {}
        column: user_id {}
        column: order_count {}
        column: total_revenue {}
        }
      datagroup_trigger: training_ecommerce_default_datagroup
    }
    dimension: order_id {
      description: ""
      type: number
    }
    dimension: user_id {
      description: ""
      type: number
    }
    dimension: order_count {
      description: ""
      type: number
    }
    dimension: total_revenue {
      description: ""
      value_format: "$#,##0.00"
      type: number
    }
 }



 WITH order_details_summary AS (SELECT
    order_items.order_id  AS order_id,
    order_items.user_id  AS user_id,
    COUNT(DISTINCT order_items.order_id ) AS order_count,
    COALESCE(SUM(order_items.sale_price ), 0) AS total_revenue
FROM `cloud-training-demos.looker_ecomm.order_items`
     AS order_items
GROUP BY
    1,
    2)
SELECT
    order_details_summary.order_count AS order_details_summary_order_count,
    order_details_summary.order_id AS order_details_summary_order_id,
    order_details_summary.total_revenue AS order_details_summary_total_revenue,
    order_details_summary.user_id AS order_details_summary_user_id
FROM `cloud-training-demos.looker_ecomm.order_items`
     AS order_items
FULL OUTER JOIN order_details_summary ON order_items.order_id=order_details_summary.order_id
GROUP BY
    1,
    2,
    3,
    4
ORDER BY
    1
LIMIT 500



WITH order_details AS (SELECT
        order_items.order_id AS order_id
        ,order_items.user_id AS user_id
        ,COUNT(*) AS order_item_count
        ,SUM(order_items.sale_price) AS order_revenue
      FROM cloud-training-demos.looker_ecomm.order_items
      GROUP BY order_id, user_id
       )
SELECT
    order_details.order_id  AS order_details_order_id,
    order_details.order_item_count  AS order_details_order_item_count,
    order_details.order_revenue  AS order_details_order_revenue,
    order_details.user_id  AS order_details_user_id
FROM `cloud-training-demos.looker_ecomm.order_items`
     AS order_items
LEFT JOIN order_details ON order_items.order_id = order_details.order_id
GROUP BY
    1,
    2,
    3,
    4
ORDER BY
    1
LIMIT 500