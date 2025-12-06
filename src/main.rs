use actix_web::{get, web, App, Error, HttpResponse, HttpServer};
use chrono::{DateTime, FixedOffset, Local, TimeZone};
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Debug, Serialize, Deserialize)]
struct InterfaceStatus {
    interface: String,
    last_handshake: String,
}

fn get_interface_status(name: &str) -> Result<InterfaceStatus, String> {
    let output = Command::new("sudo")
        .args(&[
            "wg",//command
            "show",
            name,
            "latest-handshakes",
        ])
        .output()
        .map_err(|e| format!("Failed to execute lvs: {}", e))?;

    if !output.status.success() {
        return Err(format!("lvs command failed: {}", String::from_utf8_lossy(&output.stderr)));
    }

    let stdout = std::str::from_utf8(&output.stdout)
        .map_err(|e| format!("Failed to parse lvs output: {}", e))?;

    let latest_handshake = stdout
        .lines()
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| line.trim().split(' ').last())
        .filter_map(|line| line.trim().split('\t').last())
        .filter_map(|s| s.parse::<i64>().ok())
        .max();

    let timestamp = DateTime::from_timestamp(latest_handshake.unwrap_or(0), 0)
        .ok_or_else(|| "".to_string())?;

    let local_timestamp = Local::from_offset(&FixedOffset::east_opt(0).unwrap())
        .from_utc_datetime(&timestamp.naive_utc());

    let last_handshake = local_timestamp.format("%Y-%m-%d %H:%M:%S").to_string();

    Ok(InterfaceStatus {
        interface: name.into(),
        last_handshake
    })
}

#[get("/interface/{name}")]
async fn interface_status_route(path: web::Path<String>) -> Result<HttpResponse, Error> {
    match get_interface_status(&path.into_inner()) {
        Ok(stat) => {
            Ok(HttpResponse::Ok().json(stat))
        }
        Err(e) => {
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": e
            })))
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let host = std::env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = std::env::var("PORT").unwrap_or_else(|_| "9001".to_string());

    HttpServer::new(|| {
        App::new()
            .service(interface_status_route)
    })
        .bind(format!("{}:{}", host, port))?
        .run()
        .await
}