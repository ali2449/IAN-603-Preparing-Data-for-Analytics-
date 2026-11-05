"""
Reusable PostgreSQL helper for IAN 603 notebooks.

Features
--------
- pgAdmin-style connection form using ipywidgets
- sensible PostgreSQL defaults
- optional persistence of connection settings
- optional local password persistence
- SQLAlchemy engine management
- query execution
- multi-statement script execution
- notebook-friendly SQL/result display

Typical notebook use
--------------------
from ian603_database import IAN603Database

db = IAN603Database()
db.show_connection_panel()

# After clicking Connect:
db.display_query("SELECT * FROM patients LIMIT 5;")
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


class IAN603Database:
    """Reusable PostgreSQL connection and query helper for IAN 603."""

    DEFAULT_CONFIG = {
        "host": "localhost",
        "database": "postgres",
        "user": "postgres",
        "port": 5432,
        "password": "",
    }

    def __init__(
        self,
        defaults: Optional[dict[str, Any]] = None,
        config_path: Optional[str | Path] = None,
    ) -> None:
        self.defaults = self.DEFAULT_CONFIG.copy()
        if defaults:
            self.defaults.update(defaults)

        self.config_path = (
            Path(config_path).expanduser()
            if config_path
            else Path.home() / ".ian603_postgres_connection.json"
        )

        self.engine = None
        self.widgets = {}
        self.status_output = None

    @property
    def connected(self) -> bool:
        """Return True when a SQLAlchemy engine has been created successfully."""
        return self.engine is not None

    # ------------------------------------------------------------------
    # Configuration persistence
    # ------------------------------------------------------------------

    def load_config(self) -> dict[str, Any]:
        """Load saved settings, falling back to course defaults."""
        config = self.defaults.copy()

        if self.config_path.exists():
            try:
                saved = json.loads(
                    self.config_path.read_text(encoding="utf-8")
                )
                for key in self.defaults:
                    if key in saved:
                        config[key] = saved[key]
            except Exception:
                # A damaged settings file should not stop the notebook.
                pass

        return config

    def save_config(
        self,
        config: dict[str, Any],
        save_password: bool = False,
    ) -> None:
        """Save connection settings locally."""
        data = {
            "host": config["host"],
            "database": config["database"],
            "user": config["user"],
            "port": int(config["port"]),
        }

        if save_password:
            data["password"] = config.get("password", "")

        self.config_path.write_text(
            json.dumps(data, indent=2),
            encoding="utf-8",
        )

    def forget_saved_config(self) -> None:
        """Delete the locally saved configuration file."""
        if self.config_path.exists():
            self.config_path.unlink()

    # ------------------------------------------------------------------
    # Connection panel
    # ------------------------------------------------------------------

    def _current_widget_config(self) -> dict[str, Any]:
        """Read connection values from the visible widgets."""
        if not self.widgets:
            return self.load_config()

        return {
            "host": self.widgets["host"].value.strip() or "localhost",
            "database": self.widgets["database"].value.strip() or "postgres",
            "user": self.widgets["user"].value.strip() or "postgres",
            "password": self.widgets["password"].value,
            "port": int(self.widgets["port"].value or 5432),
        }

    def show_connection_panel(self):
        """Display a pgAdmin-style connection panel in Jupyter."""
        try:
            import ipywidgets as widgets
            from IPython.display import display, clear_output
        except ImportError as exc:
            raise ImportError(
                "ipywidgets is required for the connection panel. "
                "Run: %pip install ipywidgets"
            ) from exc

        saved = self.load_config()

        host_box = widgets.Text(
            value=str(saved.get("host", "localhost")),
            description="Host:",
            placeholder="localhost",
            layout=widgets.Layout(width="430px"),
        )

        database_box = widgets.Text(
            value=str(saved.get("database", "postgres")),
            description="Database:",
            placeholder="postgres",
            layout=widgets.Layout(width="430px"),
        )

        user_box = widgets.Text(
            value=str(saved.get("user", "postgres")),
            description="Username:",
            placeholder="postgres",
            layout=widgets.Layout(width="430px"),
        )

        password_box = widgets.Password(
            value=str(saved.get("password", "")),
            description="Password:",
            placeholder="Enter PostgreSQL password",
            layout=widgets.Layout(width="430px"),
        )

        port_box = widgets.IntText(
            value=int(saved.get("port", 5432)),
            description="Port:",
            layout=widgets.Layout(width="430px"),
        )

        save_settings_box = widgets.Checkbox(
            value=True,
            description="Save connection settings for next run",
            indent=False,
        )

        save_password_box = widgets.Checkbox(
            value=False,
            description="Save password locally",
            indent=False,
        )

        connect_button = widgets.Button(
            description="Connect",
            button_style="success",
            icon="database",
            layout=widgets.Layout(width="145px"),
        )

        defaults_button = widgets.Button(
            description="Use Defaults",
            icon="refresh",
            layout=widgets.Layout(width="145px"),
        )

        forget_button = widgets.Button(
            description="Forget Saved",
            button_style="warning",
            icon="trash",
            layout=widgets.Layout(width="145px"),
        )

        self.status_output = widgets.Output()

        self.widgets = {
            "host": host_box,
            "database": database_box,
            "user": user_box,
            "password": password_box,
            "port": port_box,
            "save_settings": save_settings_box,
            "save_password": save_password_box,
        }

        def on_connect(_):
            with self.status_output:
                clear_output()
                self.connect(
                    config=self._current_widget_config(),
                    save_settings=save_settings_box.value,
                    save_password=save_password_box.value,
                    verbose=True,
                )

        def on_defaults(_):
            host_box.value = str(self.defaults["host"])
            database_box.value = str(self.defaults["database"])
            user_box.value = str(self.defaults["user"])
            password_box.value = ""
            port_box.value = int(self.defaults["port"])

            with self.status_output:
                clear_output()
                print("Defaults restored. Click Connect when ready.")

        def on_forget(_):
            self.forget_saved_config()

            with self.status_output:
                clear_output()
                print("Saved connection settings removed.")
                print("The visible fields were not changed.")

        connect_button.on_click(on_connect)
        defaults_button.on_click(on_defaults)
        forget_button.on_click(on_forget)

        title = widgets.HTML(
            """
            <div style="
                padding:12px 16px;
                background:#f3f4f6;
                border:1px solid #d1d5db;
                border-radius:8px 8px 0 0;
                font-weight:700;
                font-size:16px;">
                PostgreSQL Connection
            </div>
            """
        )

        help_text = widgets.HTML(
            """
            <div style="
                padding:8px 0 2px 0;
                color:#4b5563;
                font-size:12px;">
                Password saving is optional and stores the password as plain
                text in the local configuration file. Leave it unchecked on
                shared computers.
            </div>
            """
        )

        form = widgets.VBox(
            [
                host_box,
                database_box,
                user_box,
                password_box,
                port_box,
                widgets.HTML("<hr style='margin:8px 0;'>"),
                save_settings_box,
                save_password_box,
                help_text,
                widgets.HBox(
                    [connect_button, defaults_button, forget_button],
                    layout=widgets.Layout(gap="8px"),
                ),
                self.status_output,
            ],
            layout=widgets.Layout(
                border="1px solid #d1d5db",
                padding="16px",
                width="540px",
            ),
        )

        panel = widgets.VBox(
            [title, form],
            layout=widgets.Layout(width="540px"),
        )

        display(panel)
        return None

    # ------------------------------------------------------------------
    # Database connection
    # ------------------------------------------------------------------

    def connect(
        self,
        config: Optional[dict[str, Any]] = None,
        *,
        save_settings: bool = False,
        save_password: bool = False,
        verbose: bool = True,
    ) -> bool:
        """Connect to PostgreSQL and optionally persist the settings."""
        config = (config or self.load_config()).copy()

        connection_url = URL.create(
            drivername="postgresql+psycopg2",
            username=config["user"],
            password=config.get("password", ""),
            host=config["host"],
            port=int(config["port"]),
            database=config["database"],
        )

        try:
            test_engine = create_engine(
                connection_url,
                pool_pre_ping=True,
                echo=False,
            )

            with test_engine.connect() as conn:
                result = conn.execute(
                    text(
                        """
                        SELECT
                            current_database() AS database_name,
                            current_user AS database_user,
                            version() AS postgres_version;
                        """
                    )
                ).mappings().one()

            self.engine = test_engine

            if save_settings:
                self.save_config(
                    config,
                    save_password=save_password,
                )

            if verbose:
                print("Database connection successful.")
                print(f"Host: {config['host']}")
                print(f"Port: {config['port']}")
                print(f"Database: {result['database_name']}")
                print(f"User: {result['database_user']}")
                print(
                    "PostgreSQL:",
                    result["postgres_version"].split(",")[0],
                )

                if save_settings:
                    print(f"\nSaved settings: {self.config_path}")
                    if save_password:
                        print("Password was also saved locally.")
                    else:
                        print("Password was not saved.")

            return True

        except Exception as exc:
            self.engine = None

            if verbose:
                print("Connection failed.")
                print(exc)
                print(
                    "\nCheck the host, database, username, password, port, "
                    "and confirm PostgreSQL is running."
                )

            return False

    def require_connection(self) -> None:
        """Raise a clear error if the database is not connected."""
        if self.engine is None:
            raise RuntimeError(
                "No active PostgreSQL connection. "
                "Run db.show_connection_panel() and click Connect first."
            )

    def test_connection(self, verbose: bool = True) -> pd.DataFrame:
        """Verify the active connection and return connection information."""
        self.require_connection()

        df = self.execute_query(
            """
            SELECT
                version() AS postgres_version,
                current_database() AS database_name,
                current_user AS database_user;
            """
        )

        if verbose and not df.empty:
            print("Connection is ready.")
            print("Database:", df.loc[0, "database_name"])
            print("User:", df.loc[0, "database_user"])
            print(
                "PostgreSQL:",
                df.loc[0, "postgres_version"].split(",")[0],
            )

        return df

    # ------------------------------------------------------------------
    # Query helpers
    # ------------------------------------------------------------------

    def execute_query(
        self,
        query: str,
        params: Optional[dict[str, Any]] = None,
    ) -> pd.DataFrame:
        """Execute SQL and return any returned rows as a DataFrame."""
        self.require_connection()

        try:
            with self.engine.begin() as conn:
                result = conn.execute(text(query), params or {})

                if result.returns_rows:
                    return pd.DataFrame(
                        result.fetchall(),
                        columns=result.keys(),
                    )

                return pd.DataFrame()

        except Exception as exc:
            print("Error executing query:")
            print(exc)
            print("\nSQL:")
            print(query[:1000])
            return pd.DataFrame()

    def execute_script(self, sql_script: str) -> None:
        """Execute a multi-statement PostgreSQL script."""
        self.require_connection()

        raw_conn = self.engine.raw_connection()

        try:
            cursor = raw_conn.cursor()
            cursor.execute(sql_script)
            raw_conn.commit()
            cursor.close()
            print("SQL script executed successfully.")

        except Exception as exc:
            raw_conn.rollback()
            print("Error executing SQL script:")
            print(exc)

        finally:
            raw_conn.close()

    def display_query(
        self,
        query: str,
        title: Optional[str] = None,
        params: Optional[dict[str, Any]] = None,
        max_rows: int = 50,
        return_df: bool = False,
    ):
        """
        Display SQL and query results once.

        Set return_df=True only when later Python code needs the DataFrame.
        """
        try:
            from IPython.display import display, Markdown
        except ImportError as exc:
            raise ImportError(
                "IPython is required for notebook display helpers."
            ) from exc

        if title:
            display(Markdown(f"### {title}"))

        display(
            Markdown(
                f"""```sql
{query.strip()}
```"""
            )
        )

        df = self.execute_query(query, params=params)

        if df.empty:
            display(
                Markdown(
                    "*Query executed successfully, but no rows were returned.*"
                )
            )
        elif len(df) > max_rows:
            display(
                Markdown(
                    f"*Showing first {max_rows:,} of {len(df):,} rows.*"
                )
            )
            display(df.head(max_rows))
        else:
            display(df)

        if return_df:
            return df

        return None