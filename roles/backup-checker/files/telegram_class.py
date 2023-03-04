#!/usr/bin/env python
# coding: utf-8

import sys
import requests

def print_message(message):
    message = str(message) + "\n"
    filename = sys.argv[0].split("/")[-1]
    sys.stderr.write(filename + ": " + message)


class TelegramAPI:
    tg_url_bot_general = "https://api.telegram.org/bot"

    def http_get(self, url):
        answer = requests.get(url, proxies=self.proxies)
        self.result = answer.json()
        self.ok_update()
        return self.result

    def __init__(self, key):
        self.debug = False
        self.key = key
        self.proxies = {}
        self.type = "private"  # 'private' for private chats or 'group' for group chats
        self.markdown = False
        self.html = False
        self.disable_web_page_preview = False
        self.disable_notification = False
        self.reply_to_message_id = 0
        self.tmp_dir = None
        self.tmp_uids = None
        self.location = {"latitude": None, "longitude": None}
        self.update_offset = 0
        self.image_buttons = False
        self.result = None
        self.ok = None
        self.error = None
        self.get_updates_from_file = False

    def get_me(self):
        url = self.tg_url_bot_general + self.key + "/getMe"
        me = self.http_get(url)
        return me

    def send_message(self, to, message):
        url = self.tg_url_bot_general + self.key + "/sendMessage"
        message = "\n".join(message)
        params = {"chat_id": to, "text": message, "disable_web_page_preview": self.disable_web_page_preview,
                  "disable_notification": self.disable_notification}
        if self.reply_to_message_id:
            params["reply_to_message_id"] = self.reply_to_message_id
        if self.markdown or self.html:
            parse_mode = "HTML"
            if self.markdown:
                parse_mode = "Markdown"
            params["parse_mode"] = parse_mode
        if self.debug:
            print_message("Trying to /sendMessage:")
            print_message(url)
            print_message("post params: " + str(params))
        answer = requests.post(url, params=params, proxies=self.proxies)
        if answer.status_code == 414:
            self.result = {"ok": False, "description": "414 URI Too Long"}
        else:
            self.result = answer.json()
        self.ok_update()
        return self.result

    def ok_update(self):
        self.ok = self.result["ok"]
        if self.ok:
            self.error = None
        else:
            self.error = self.result["description"]
            print_message(self.error)
        return True

if __name__ == "__main__":
    print("Telegram class")
    exit()
