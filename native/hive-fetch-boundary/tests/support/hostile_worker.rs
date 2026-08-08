use std::io::{self, Write};
use std::thread;
use std::time::Duration;

use hive_fetch_boundary::protocol::{
    write_response, CodecConfig, WorkerResponse, PROTOCOL_VERSION,
};

fn main() {
    let stdout = io::stdout();
    let mut writer = stdout.lock();
    write_response(
        &mut writer,
        &WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        },
        CodecConfig::default(),
    )
    .expect("write hostile worker Ready response");
    writer.flush().expect("flush hostile worker Ready response");

    // Deliberately do not read stdin. This child models a worker that is alive,
    // has completed startup, and ignores cooperative shutdown. The supervisor
    // must enforce its watchdog with kill + wait rather than relying on EOF.
    loop {
        thread::sleep(Duration::from_millis(25));
    }
}
