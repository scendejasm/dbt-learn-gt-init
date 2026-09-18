-- Import CTEs
with customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

orders as (
    select * from {{ ref('int_orders') }}
),
--------------------------------------------

customer_orders as (

    select
        orders.*,
        customers.full_name,
        customers.givenname,
        customers.surname,

        -- customer level aggregations 
        min(order_date) over(
            partition by orders.customer_id
        ) as first_order_date,

        min( valid_order_date ) over(
            partition by orders.customer_id
        ) as first_non_returned_order_date,

        max( valid_order_date ) over(
            partition by orders.customer_id
        ) as most_recent_non_returned_order_date,
        
        count(*) over (
            partition by orders.customer_id
        ) as order_count,

        sum(
            nvl2(orders.valid_order_date, 1, 0)
        ) over (
            partition by orders.customer_id
        ) as non_returned_order_count,

        sum(
            nvl2(orders.valid_order_date, orders.order_value_dollars, 0) 
        ) over (
            partition by orders.customer_id
        ) as total_lifetime_value

        -- array_agg(distinct orders.order_id) over (
        --     partition by orders.customer_id
        -- ) as order_ids


    from orders
    inner join customers 
    on orders.customer_id = customers.customer_id

),

add_avg_order_values as (

    select
        customer_orders.*,
        total_lifetime_value / non_returned_order_count as avg_non_returned_order_value
    from customer_orders

),

--------------------------------------------

-- Final CTE
final as (

    select

        order_id,
        customer_id,
        surname,
        givenname,
        first_order_date, 
        order_count,
        total_lifetime_value,
        order_value_dollars, -- pay attention here while auditing
        order_status,
        payment_status

    from add_avg_order_values

)

-- Final Select 
select * from final