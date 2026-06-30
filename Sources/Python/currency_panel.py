#!/usr/bin/env python3
import json
import math
import os
import threading
import time
import tkinter as tk
from tkinter import ttk
from urllib.request import urlopen


API_URL = "https://open.er-api.com/v6/latest/USD"
STATE_PATH = os.path.expanduser("~/Library/Application Support/CurrencyPanel/state.json")
REFRESH_SECONDS = 30 * 60

CURRENCIES = [
    ("KRW", "Korean Won", "South Korea", "🇰🇷"),
    ("JPY", "Japanese Yen", "Japan", "🇯🇵"),
    ("CNY", "Chinese Yuan", "China", "🇨🇳"),
    ("EUR", "Euro", "Eurozone", "🇪🇺"),
    ("GBP", "British Pound", "United Kingdom", "🇬🇧"),
    ("AUD", "Australian Dollar", "Australia", "🇦🇺"),
    ("CAD", "Canadian Dollar", "Canada", "🇨🇦"),
    ("CHF", "Swiss Franc", "Switzerland", "🇨🇭"),
    ("HKD", "Hong Kong Dollar", "Hong Kong", "🇭🇰"),
    ("TWD", "New Taiwan Dollar", "Taiwan", "🇹🇼"),
    ("SGD", "Singapore Dollar", "Singapore", "🇸🇬"),
    ("THB", "Thai Baht", "Thailand", "🇹🇭"),
    ("VND", "Vietnamese Dong", "Vietnam", "🇻🇳"),
    ("PHP", "Philippine Peso", "Philippines", "🇵🇭"),
    ("IDR", "Indonesian Rupiah", "Indonesia", "🇮🇩"),
    ("MYR", "Malaysian Ringgit", "Malaysia", "🇲🇾"),
    ("NZD", "New Zealand Dollar", "New Zealand", "🇳🇿"),
    ("MXN", "Mexican Peso", "Mexico", "🇲🇽"),
    ("BRL", "Brazilian Real", "Brazil", "🇧🇷"),
    ("INR", "Indian Rupee", "India", "🇮🇳"),
]

DEFAULT_CODES = ["KRW", "JPY", "CNY", "EUR", "GBP", "AUD", "CAD", "HKD", "TWD", "SGD"]


class CurrencyPanel:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("CurrencyPanel")
        self.root.geometry("500x720+900+80")
        self.root.minsize(440, 560)
        self.root.configure(bg="#202124")
        self.root.attributes("-topmost", True)
        self.root.bind("<Command-q>", lambda event: self.root.destroy())
        self.root.protocol("WM_DELETE_WINDOW", self.root.withdraw)

        self.amount = tk.DoubleVar(value=1.0)
        self.status = tk.StringVar(value="환율 불러오는 중")
        self.updated = tk.StringVar(value="업데이트 대기 중")
        self.rates = {}
        self.previous_rates = {}
        self.selected_codes = set(DEFAULT_CODES)
        self.rows = {}

        self.load_state()
        self.build_ui()
        self.refresh_async()
        self.schedule_refresh()

    def load_state(self):
        try:
            with open(STATE_PATH, "r", encoding="utf-8") as handle:
                state = json.load(handle)
        except Exception:
            return

        self.amount.set(float(state.get("amount", 1.0) or 1.0))
        self.previous_rates = state.get("previous_rates", {}) or {}
        saved_codes = state.get("selected_codes")
        if saved_codes:
            self.selected_codes = set(saved_codes)

    def save_state(self):
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        state = {
            "amount": self.amount.get(),
            "previous_rates": self.previous_rates,
            "selected_codes": sorted(self.selected_codes),
        }
        with open(STATE_PATH, "w", encoding="utf-8") as handle:
            json.dump(state, handle)

    def build_ui(self):
        self.main = tk.Frame(self.root, bg="#202124", padx=18, pady=18)
        self.main.pack(fill="both", expand=True)

        header = tk.Frame(self.main, bg="#202124")
        header.pack(fill="x")

        tk.Label(header, text="🇺🇸", font=("Apple Color Emoji", 30), bg="#f4f4f4", width=3).pack(side="left")
        title_box = tk.Frame(header, bg="#202124")
        title_box.pack(side="left", padx=12)
        tk.Label(title_box, text="U.S. Dollar", fg="#f2f2f2", bg="#202124", font=("Helvetica", 24, "bold")).pack(anchor="w")
        tk.Label(title_box, text="USD 기준", fg="#aeb0b5", bg="#202124", font=("Helvetica", 14, "bold")).pack(anchor="w")

        amount_entry = tk.Entry(
            header,
            textvariable=self.amount,
            justify="right",
            width=7,
            fg="#f2f2f2",
            bg="#303134",
            insertbackground="#f2f2f2",
            relief="flat",
            font=("Menlo", 30),
        )
        amount_entry.pack(side="right")
        amount_entry.bind("<KeyRelease>", lambda event: self.render_values())

        status_row = tk.Frame(self.main, bg="#202124")
        status_row.pack(fill="x", pady=(10, 12))
        tk.Label(status_row, textvariable=self.status, fg="#aeb0b5", bg="#202124", font=("Helvetica", 12, "bold")).pack(side="left")

        cross = tk.Frame(self.main, bg="#202124")
        cross.pack(fill="x", pady=(0, 12))
        self.jpy_cross = self.cross_card(cross, "1,000원 -> 엔")
        self.jpy_cross.pack(side="left", fill="x", expand=True, padx=(0, 5))
        self.cny_cross = self.cross_card(cross, "1,000원 -> 위안")
        self.cny_cross.pack(side="left", fill="x", expand=True, padx=(5, 0))

        self.canvas = tk.Canvas(self.main, bg="#202124", highlightthickness=0)
        scrollbar = ttk.Scrollbar(self.main, orient="vertical", command=self.canvas.yview)
        self.list_frame = tk.Frame(self.canvas, bg="#202124")
        self.list_frame.bind("<Configure>", lambda event: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas_window = self.canvas.create_window((0, 0), window=self.list_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=scrollbar.set)
        self.canvas.bind("<Configure>", lambda event: self.canvas.itemconfigure(self.canvas_window, width=event.width))
        self.canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        footer = tk.Frame(self.main, bg="#202124")
        footer.pack(fill="x", pady=(12, 0))
        tk.Label(footer, textvariable=self.updated, fg="#aeb0b5", bg="#202124", font=("Helvetica", 12, "bold")).pack(side="left")
        tk.Button(footer, text="↻", command=self.refresh_async, width=3).pack(side="right", padx=(6, 0))
        tk.Button(footer, text="통화", command=self.open_picker, width=6).pack(side="right")

        self.render_rows()

    def cross_card(self, parent, label):
        frame = tk.Frame(parent, bg="#303134", padx=12, pady=10)
        tk.Label(frame, text=label, fg="#aeb0b5", bg="#303134", font=("Helvetica", 12, "bold")).pack(anchor="w")
        value = tk.Label(frame, text="--", fg="#f2f2f2", bg="#303134", font=("Menlo", 20, "bold"))
        value.pack(anchor="w")
        delta = tk.Label(frame, text="new", fg="#aeb0b5", bg="#303134", font=("Helvetica", 11, "bold"))
        delta.pack(anchor="w")
        return {"frame": frame, "value": value, "delta": delta}

    def render_rows(self):
        for child in self.list_frame.winfo_children():
            child.destroy()
        self.rows.clear()

        for code, name, _country, flag in CURRENCIES:
            if code not in self.selected_codes:
                continue
            card = tk.Frame(self.list_frame, bg="#17181b", padx=12, pady=10)
            card.pack(fill="x", pady=5)

            left = tk.Frame(card, bg="#17181b")
            left.pack(side="left")
            tk.Label(left, text=flag, font=("Apple Color Emoji", 26), bg="#f4f4f4", width=3).pack(side="left")
            name_box = tk.Frame(left, bg="#17181b")
            name_box.pack(side="left", padx=12)
            tk.Label(name_box, text=name, fg="#f2f2f2", bg="#17181b", font=("Helvetica", 18, "bold")).pack(anchor="w")
            tk.Label(name_box, text=code, fg="#aeb0b5", bg="#17181b", font=("Helvetica", 13, "bold")).pack(anchor="w")

            value_box = tk.Frame(card, bg="#17181b")
            value_box.pack(side="right")
            value = tk.Label(value_box, text="--", fg="#f2f2f2", bg="#17181b", font=("Menlo", 27))
            value.pack(anchor="e")
            delta = tk.Label(value_box, text="new", fg="#aeb0b5", bg="#17181b", font=("Helvetica", 11, "bold"))
            delta.pack(anchor="e")
            self.rows[code] = {"value": value, "delta": delta}

        self.render_values()

    def render_values(self):
        amount = self.safe_amount()
        for code, widgets in self.rows.items():
            rate = self.rates.get(code)
            widgets["value"].configure(text=self.format_number(rate * amount) if rate else "--")
            self.configure_delta(widgets["delta"], self.delta(code))

        self.configure_cross("JPY", self.jpy_cross)
        self.configure_cross("CNY", self.cny_cross)

    def configure_cross(self, code, widgets):
        krw = self.rates.get("KRW")
        target = self.rates.get(code)
        if krw and target:
            widgets["value"].configure(text=self.format_number(1000 * target / krw, 4))
        else:
            widgets["value"].configure(text="--")
        self.configure_delta(widgets["delta"], self.cross_delta(code))

    def configure_delta(self, label, value):
        if value is None:
            label.configure(text="new", fg="#aeb0b5")
            return
        label.configure(text=f"{value:+.2f}%", fg="#6ee787" if value >= 0 else "#ff7b72")

    def safe_amount(self):
        try:
            value = float(self.amount.get())
            return value if value > 0 and math.isfinite(value) else 1.0
        except Exception:
            return 1.0

    def delta(self, code):
        current = self.rates.get(code)
        previous = self.previous_rates.get(code)
        if not current or not previous or current == previous:
            return None
        return ((current - previous) / previous) * 100

    def cross_delta(self, code):
        now_krw = self.rates.get("KRW")
        now_target = self.rates.get(code)
        old_krw = self.previous_rates.get("KRW")
        old_target = self.previous_rates.get(code)
        if not all([now_krw, now_target, old_krw, old_target]):
            return None
        current = now_target / now_krw
        previous = old_target / old_krw
        if current == previous:
            return None
        return ((current - previous) / previous) * 100

    def format_number(self, value, digits=3):
        return f"{value:,.{digits}f}".rstrip("0").rstrip(".")

    def refresh_async(self):
        self.status.set("환율 불러오는 중")
        threading.Thread(target=self.fetch_rates, daemon=True).start()

    def fetch_rates(self):
        try:
            with urlopen(API_URL, timeout=12) as response:
                payload = json.loads(response.read().decode("utf-8"))
            rates = payload["rates"]
            if self.rates:
                self.previous_rates = self.rates
            elif not self.previous_rates:
                self.previous_rates = rates
            self.rates = rates
            updated = time.strftime("%-m/%-d %H:%M", time.localtime(payload.get("time_last_update_unix", time.time())))
            self.root.after(0, lambda: self.apply_refresh(updated))
        except Exception as error:
            self.root.after(0, lambda: self.status.set(f"환율 오류: {error}"))

    def apply_refresh(self, updated):
        self.status.set("30분마다 자동 갱신")
        self.updated.set(updated)
        self.render_values()
        self.save_state()

    def schedule_refresh(self):
        self.root.after(REFRESH_SECONDS * 1000, self.scheduled_refresh)

    def scheduled_refresh(self):
        self.refresh_async()
        self.schedule_refresh()

    def open_picker(self):
        picker = tk.Toplevel(self.root)
        picker.title("통화 선택")
        picker.geometry("390x560")
        picker.attributes("-topmost", True)
        variables = {}

        body = tk.Frame(picker, padx=14, pady=14)
        body.pack(fill="both", expand=True)

        for code, name, country, flag in CURRENCIES:
            var = tk.BooleanVar(value=code in self.selected_codes)
            variables[code] = var
            tk.Checkbutton(body, text=f"{flag}  {name} · {code} · {country}", variable=var, anchor="w").pack(fill="x", pady=2)

        def apply_selection():
            selected = {code for code, var in variables.items() if var.get()}
            self.selected_codes = selected or {"KRW"}
            self.save_state()
            self.render_rows()
            picker.destroy()

        tk.Button(body, text="완료", command=apply_selection).pack(fill="x", pady=(12, 0))

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    CurrencyPanel().run()
