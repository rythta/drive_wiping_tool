use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture /*, Event, KeyCode, self */},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use std::io::{self, BufRead, BufReader, Write};
use std::fs;  // Corrected: Added this line to fix the error
use std::fs::File;
use std::collections::HashMap;
use std::os::unix::net::{/* UnixStream, */ UnixListener};  // Corrected: Commented out UnixStream
use tui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout},
    style::{Color, Style},
    widgets::{Block, Borders},
    Frame, Terminal,
};

const WIDTH: u16 = 4;
const HEIGHT: u16 = 6;

#[derive(Clone)]
enum Status {
    None,
    Passed,
    Failed,
    Working,  // Added the Working variant
}

#[derive(Clone)]
struct Bay {
    title: String,
    status: Status,
}

impl Default for Bay {
    fn default() -> Bay {
        Bay {
            title: "empty".to_string(),
            status: Status::None,
        }
    }
}

struct Bays {
    data: Vec<Vec<Bay>>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    terminal.clear()?;

    let config = fs::read_to_string("/etc/dw9k.conf").unwrap_or_else(|_| {
        eprintln!("Missing config file");
        std::process::exit(1);
    });

    let mut port_layout = HashMap::<String, [usize; 2]>::new();
    let mut y: usize = 0;
    for row in config.lines() {
        let mut x: usize = 0;
        for port in row.split_whitespace() {
            port_layout.insert(port.to_string(), [y, x]);
            x += 1;
        }
        y += 1;
    }

    let res = run_app(&mut terminal, &port_layout);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture)?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Application error: {:?}", err);
    }

    Ok(())
}

fn parse_status(status_str: &str) -> Status {
    match status_str {
        "none" => Status::None,
        "working" => Status::Working,
        "passed" => Status::Passed,
        "failed" => Status::Failed,
        _ => Status::None, // Default case
    }
}

fn run_app<B: Backend>(terminal: &mut Terminal<B>, port_layout: &HashMap<String, [usize; 2]>) -> io::Result<()> {
    let mut bays = Bays {
        data: vec![vec![Bay::default(); WIDTH as usize]; HEIGHT as usize],
    };
    let listener = UnixListener::bind("/tmp/dw9k.sock")?;

    let mut log = File::create("/tmp/dw9k.log")?;

    terminal.draw(|f| ui(f, &mut bays))?;

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let stream = BufReader::new(stream);
                for line in stream.lines() {
                    let line = line?;
                    log.write_all(line.as_bytes())?;
                    log.write_all(b"\n")?;

                    let v: Vec<&str> = line.split_whitespace().collect();
                    if v.len() == 3 {
                        if let Some(coord) = port_layout.get(v[0]) {
                            bays.data[coord[0]][coord[1]].title = v[1].to_string();
                            bays.data[coord[0]][coord[1]].status = parse_status(v[2]);
                        }
                    }
                    terminal.draw(|f| ui(f, &mut bays))?;
                }
            }
            Err(e) => {
                eprintln!("Stream error: {}", e);
                break;
            }
        }
    }

    Ok(())
}

const TOTAL_PERCENTAGE: u16 = 100;

fn ui<B: Backend>(f: &mut Frame<B>, bays: &mut Bays) {
    let mut size = f.size();

    // Ensure size adjustment logic is robust and overflow-free
    let width_adjustment = (TOTAL_PERCENTAGE as f32 / WIDTH.max(1) as f32 * WIDTH as f32).round() as u16;
    size.x = size.x.saturating_add(TOTAL_PERCENTAGE.saturating_sub(width_adjustment));

    // Use floating-point arithmetic for precise percentage calculation
    let row_percentage = (TOTAL_PERCENTAGE as f32 / HEIGHT.max(1) as f32).round() as u16;
    let row_constraints = vec![Constraint::Percentage(row_percentage); HEIGHT as usize];
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints(row_constraints)
        .split(size);

    for i in 0..HEIGHT as usize {
        let col_percentage = (TOTAL_PERCENTAGE as f32 / WIDTH.max(1) as f32).round() as u16;
        let col_constraints = vec![Constraint::Percentage(col_percentage); WIDTH as usize];
        let cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(col_constraints)
            .split(rows[i]);

        for j in 0..WIDTH as usize {
            let block = Block::default()
                .title(bays.data[i][j].title.clone())
                .borders(Borders::ALL);
            f.render_widget(block, cols[j]);

            let status_area = Layout::default()
                .constraints([Constraint::Percentage(TOTAL_PERCENTAGE)].as_ref())
                .margin(1)
                .split(cols[j]);

            let status_color = match bays.data[i][j].status {
                Status::None => continue, // Skip rendering for Status::None
                Status::Passed => Color::Green,
                Status::Failed => Color::Red,
                Status::Working => Color::Yellow,
            };

            let status_block = Block::default()
                .style(Style::default().bg(status_color));
            f.render_widget(status_block, status_area[0]);
        }
    }
}
