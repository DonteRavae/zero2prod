use std::net::TcpListener;

#[tokio::test]
async fn health_check_works() {
    //When we receive a GET request for /health_check we return a 200 OK response with no body.

    // Arrange
    let address = spawn_app();
    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{address}/health_check"))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

// Launch application in the background ~somehow~
fn spawn_app() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
    let port = listener.local_addr().unwrap().port();
    let server = zero2prod::run(listener).expect("Failed to bind address");
    // Launch the server as a background task
    let _ = tokio::spawn(server);
    format!("http://127.0.0.1:{port}")
}
