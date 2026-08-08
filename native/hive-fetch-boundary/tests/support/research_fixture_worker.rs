use std::io::{self, BufReader, Write};

use hive_fetch_boundary::protocol::{
    read_request, write_response, CodecConfig, WorkerRequest, WorkerResponse, PROTOCOL_VERSION,
};

fn main() {
    let config = CodecConfig::default();
    let stdin = io::stdin();
    let mut reader = BufReader::new(stdin.lock());
    let stdout = io::stdout();
    let mut writer = stdout.lock();

    write_response(
        &mut writer,
        &WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        },
        config,
    )
    .expect("write fixture Ready");

    let Some(request) = read_request(&mut reader, config).expect("read fixture request") else {
        return;
    };
    match request {
        WorkerRequest::Fetch { request_id, .. } => {
            write_response(
                &mut writer,
                &WorkerResponse::FetchStarted {
                    request_id: request_id.clone(),
                },
                config,
            )
            .expect("write fixture FetchStarted");
            write_response(
                &mut writer,
                &WorkerResponse::FetchCompleted {
                    request_id,
                    status: 200,
                    final_url: "https://fixture.example/final".to_owned(),
                    content_type: Some("text/plain".to_owned()),
                    body_base64: hive_fetch_boundary::protocol::encode_body(b"fixture body"),
                    redirect_count: 2,
                },
                config,
            )
            .expect("write fixture FetchCompleted");
        }
        WorkerRequest::Shutdown { .. } => {}
        _ => {}
    }
    let _ = writer.flush();
}
