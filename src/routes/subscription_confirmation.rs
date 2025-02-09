use actix_web::{web, HttpResponse};
use anyhow::Context;
use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::{RetrieveSubscriberIdError, SubscriptionConfirmationError};

#[derive(Deserialize)]
pub struct Parameters {
    subscription_token: String,
}

#[tracing::instrument(name = "Confirming a pending subscriber", skip(db_pool, parameters))]
pub async fn confirm(
    db_pool: web::Data<PgPool>,
    parameters: web::Query<Parameters>,
) -> Result<HttpResponse, SubscriptionConfirmationError> {
    let id = get_subscriber_id_from_token(&db_pool, &parameters.subscription_token)
        .await
        .context("Failed to retrieve subscriber id from database.")?;

    match id {
        None => Ok(HttpResponse::Unauthorized().finish()),
        Some(subscriber_id) => {
            confirm_subscriber(&db_pool, subscriber_id)
                .await
                .context("Failed to confirm subscription in database.")?;
            Ok(HttpResponse::Ok().finish())
        }
    }
}

#[tracing::instrument(
    name = "Marking subscriber as confirmed in database",
    skip(db_pool, subscriber_id)
)]
async fn confirm_subscriber(db_pool: &PgPool, subscriber_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query!(
        r#"
        UPDATE subscriptions
        SET status = 'confirmed'
        WHERE id = $1
        "#,
        subscriber_id
    )
    .execute(db_pool)
    .await?;

    Ok(())
}

#[tracing::instrument(
    name = "Getting subscriber ID from token",
    skip(db_pool, subscription_token)
)]
async fn get_subscriber_id_from_token(
    db_pool: &PgPool,
    subscription_token: &str,
) -> Result<Option<Uuid>, RetrieveSubscriberIdError> {
    let result = sqlx::query!(
        r#"
        SELECT subscriber_id FROM subscription_tokens
        WHERE subscription_token = $1
        "#,
        subscription_token
    )
    .fetch_optional(db_pool)
    .await
    .map_err(RetrieveSubscriberIdError)?;

    Ok(result.map(|r| r.subscriber_id))
}
