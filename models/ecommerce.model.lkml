connection: "bigquery_public_data_looker"

# To improve efficiency of joins, be sure to join only the views that are needed to define the Explore,
# include all the views
include: "/views/*.view"
include: "/z_tests/*.lkml"
include: "/**/*.dashboard"

datagroup: order_items_datagroup {
  sql_trigger: SELECT MAX(order_item_id) from order_items  ;;
  max_cache_age: "1 hour"
}

#datagroup to work with incremental pdt view refresh
datagroup: daily_datagroup {
  sql_trigger: SELECT FORMAT_TIMESTAMP('%F',
    CURRENT_TIMESTAMP(), 'America/Los_Angeles') ;;
  max_cache_age: "24 hours"
}
#The sql_trigger checks the current date and triggers a refresh when the date changes, and max_cache_age ensures that the table will rebuild after 24 hours, even if the sql_trigger fails to run successfully.

explore: order_items {
  persist_with: order_items_datagroup
#explore level filters
#1. always_filter 2. sql_always_where 3. sql_always_having 4. Conditional filter  
  always_filter: {filters: [order_items.status: "Complete",users.country: "USA"]}
  sql_always_where: ${created_date}>='2021-01-01' ;;
  sql_always_having: ${order_count}=1 ;;
  conditionally_filter: {filters: [created_date: "3 years"] unless: [users.id, users.state]} #makes the first filter persistent until one of the mentioned unless filter is applied
  
  
  join: users {
    type: left_outer
    sql_on: ${order_items.user_id} = ${users.id} ;;
    relationship: many_to_one
  }

  join: inventory_items {
    type: left_outer
    sql_on: ${order_items.inventory_item_id} = ${inventory_items.id} ;;
    relationship: many_to_one
  }

  join: products {
    type: left_outer
    sql_on: ${inventory_items.product_id} = ${products.id} ;;
    relationship: many_to_one
  }

  join: distribution_centers {
    type: left_outer
    sql_on: ${products.distribution_center_id} = ${distribution_centers.id} ;;
    relationship: many_to_one
  }
}

explore: events {
  join: event_session_facts {
    type: left_outer
    sql_on: ${events.session_id} = ${event_session_facts.session_id} ;;
    relationship: many_to_one
  }
  join: event_session_funnel {
    type: left_outer
    sql_on: ${events.session_id} = ${event_session_funnel.session_id} ;;
    relationship: many_to_one
  }
  join: users {
    type: left_outer
    sql_on: ${events.user_id} = ${users.id} ;;
    relationship: many_to_one
  }
}

explore: incremental_pdt {}

#refinements unlike extend doesnt create a looker object but rather injects the changes directly to preexisting looker object.
explore: +order_items {
  description: "a refinement to preexisting order item explore"
  label: "Order Items - Aggregate Sales"

  aggregate_table: aggregate_sales {
    query: {
      dimensions: [order_items.created_date, users.state]
      measures: [order_items.average_sale_price,
        order_items.total_revenue]
    }
    materialization: {
      datagroup_trigger: daily_datagroup
      increment_key: "created_date"
      increment_offset: 3
    }
  }
}

#from parameter is used when the name of explore we are creating is different from the acrtual view name.
explore: aggregated_orders {
  from: order_items
  label: "Aggregated Sales"
  join: users {
    type: left_outer
    sql_on: ${aggregated_orders.user_id} = ${users.id} ;;
    relationship: many_to_one
  }
  aggregate_table: aggregate_sales {
        query: {
            dimensions: [aggregated_orders.created_date,
users.state]
            measures: [aggregated_orders.average_sale_price,
aggregated_orders.total_revenue]
        }
        materialization: {
            datagroup_trigger: daily_datagroup
     	 	increment_key: "created_date"
     	 	increment_offset: 3
        }
    }
  }
