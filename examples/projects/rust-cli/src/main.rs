use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "tasks", about = "Simple task manager CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Add a new task
    Add { title: String },
    /// List all tasks
    List,
    /// Mark a task as done
    Done { id: usize },
}

#[derive(Serialize, Deserialize)]
struct Task {
    id: usize,
    title: String,
    done: bool,
}

fn data_path() -> PathBuf {
    PathBuf::from("tasks.json")
}

fn load_tasks() -> Vec<Task> {
    match fs::read_to_string(data_path()) {
        Ok(data) => serde_json::from_str(&data).unwrap_or_default(),
        Err(_) => vec![],
    }
}

fn save_tasks(tasks: &[Task]) {
    let json = serde_json::to_string_pretty(tasks).expect("Failed to serialize");
    fs::write(data_path(), json).expect("Failed to write file");
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Add { title } => {
            let mut tasks = load_tasks();
            let id = tasks.len() + 1;
            tasks.push(Task {
                id,
                title: title.clone(),
                done: false,
            });
            save_tasks(&tasks);
            println!("Added task #{}: {}", id, title);
        }
        Commands::List => {
            let tasks = load_tasks();
            if tasks.is_empty() {
                println!("No tasks.");
                return;
            }
            for t in &tasks {
                let status = if t.done { "x" } else { " " };
                println!("[{}] #{}: {}", status, t.id, t.title);
            }
        }
        Commands::Done { id } => {
            let mut tasks = load_tasks();
            if let Some(task) = tasks.iter_mut().find(|t| t.id == id) {
                task.done = true;
                save_tasks(&tasks);
                println!("Task #{} marked as done.", id);
            } else {
                eprintln!("Task #{} not found.", id);
                std::process::exit(1);
            }
        }
    }
}
