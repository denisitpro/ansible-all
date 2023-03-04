import datetime
import logging
import os
import psycopg2
from contextlib import closing


def logme(function):
    def wrapper(*args, **kwargs):
        pass
        # print("call {0}".format(function.__name__))
        return function(*args, **kwargs)

    return wrapper


class BackupChecker:
    def __init__(self,
                 dirs=('/tmp/ttt',),
                 db_host='localhost',
                 db_name='dbname',
                 db_user='dbuser',
                 db_pass='dbpass',
                 hostname='hostname',
                 setpoint_days_diff=2,
                 setpoint_count=10,
                 setpoint_size=1,  # setpoint in Mb
                 notify_only_alarms=False,
                 test_mode=False
                 ):

        # DB params
        self.db_name = db_name
        self.db_user = db_user
        self.db_pass = db_pass
        self.db_host = db_host

        # limits to alarm
        self.setpoint_days = setpoint_days_diff
        self.setpoint_count = setpoint_count  # if count of archives less than setpoint
        self.setpoint_size = setpoint_size
        self.test_mode = test_mode
        self.notify_only_alarms = notify_only_alarms

        # misc
        self.logger = logging.getLogger("main")
        self.hostname = hostname

        # data
        self.dirs = dirs  # tuple of directories
        self.filemask = (".gz.gpg",)
        self.files_list = []
        self.data_from_DB = []
        self.data_to_update_bases = []
        self.data_add_log = []

    # ******** COMMON ********

    def set_logger(self, logger):
        self.logger = logger

    def get_stand_name(self, st):
        if isinstance(st, str):
            if (st == "hd") or (st == "ld") or (st == "dev"):
                return "dev"
            if (st == "hs") or (st == "ls") or (st == "sbx"):
                return "sbx"
            if (st == "hb") or (st == "lb") or (st == "beta"):
                return "beta"
            if (st == "hu") or (st == "lu") or (st == "uat"):
                return "uat"
            if (st == "hp") or (st == "lp") or (st == "prod"):
                return "prod"
            return "stg"

    def get_btype(self, var):
        if isinstance(var, str):
            if var.find("psql") >= 0:
                return "psql"
            if var.find("click") >= 0:
                return "clickhouse"
            if var.find("conf") >= 0:
                return "config"

    def check_in_bases(self, data):
        """Function get data{...}
            and check exists or not same source in self.data_from_DB[]
            :return id or -1 if no exists
           """
        self.logger.debug("call check_in_bases()")
        hash = '{0}_{1}_{2}'.format(self.hostname, data["stand"], data["bname"])
        self.logger.debug("hash={0}".format(hash))
        # print("self.data_from_DB", self.data_from_DB)
        if len(self.data_from_DB) > 0:
            for i in range(len(self.data_from_DB)):
                if hash == self.data_from_DB[i]["hash"]:
                    return self.data_from_DB[i]["id"], i
        return -1, 0

    def add_record_to_buffer_log(self, record):
        self.logger.debug("call add_record_to_buffer_log()")
        self.data_add_log.append(record)

    ## ********  FILES  *********

    def formFilesList(self):
        """Form list of files from dirs.
            self.files_list[]
           """
        self.logger.debug("formFilesList")
        self.files_list = []
        for dirr in self.dirs:
            if os.path.isdir(dirr):
                # dir exists
                for d, dirs, files in os.walk(dirr):
                    for f in files:
                        # print(f)
                        correct_ends = False
                        for mask in self.filemask:
                            if f.strip(' ').endswith(mask):
                                correct_ends = True
                                break
                        if correct_ends:
                            print("{0}/{1}".format(d, f))
                            size = os.path.getsize('{0}/{1}'.format(d, f))  # / 1048576
                            self.files_list.append({"dir": d, "fname": f, "size": size})
            else:
                self.logger.critical("Directory {0} not exist!".format(dirr))

    def get_data_from_file(self, data):
        """Analize filename and get fields
        return struct
        {
            "stand": value,
            "bname": value,
            "btype": value,
            "bdate": value
        }
           """
        # 1. get data from filename
        s1 = data["fname"].split('.')
        s2 = s1[0].split('_')
        length = len(s2)
        if length == 2:
            s3 = s2[0].split('-')
            if len(s3) > 1:
                name = '-'.join(s3[1:])
                stand = self.get_stand_name(s3[0])
            else:
                name = s3[0]
                stand = self.get_stand_name(' ')
        elif length == 3:
            name = s2[1]
            stand = self.get_stand_name(s2[0])
        # get data
        date = s2[-1].split('-')[0]

        # 2. get data from dir
        btype = self.get_btype(data["dir"])

        # print("filename={0}, len={1}, stand={2}, bname={3}, date={4}".format(data["fname"], length, stand, name, date))
        return {
            "stand": stand,
            "bname": name,
            "btype": btype,
            "bdate": '{0}-{1}-{2}'.format(date[0:4], date[4:6], date[6:])
        }

    def add_to_data_from_DB(self, record):
        """template to add record to list data_from_DB[]
        :return id
           """
        data = {}
        data["id"] = record[0]
        data["stand"] = record[1]
        data["bname"] = record[2]
        data["btype"] = record[3]
        data["bhost"] = record[4]
        data["last_date"] = record[5]
        data["last_size"] = record[6]
        data["hash"] = "{0}_{1}_{2}".format(data["bhost"], data["stand"], data["bname"])
        if self.test_mode:
            data["count"] = record[7]
        else:
            data["count"] = 0
        data["need_notification"] = record[8]

        if data["bhost"] == self.hostname:  # don't get data from another host
            self.data_from_DB.append(data)

        return data["id"]

    def modify_data_from_db_buffer(self, position, date, size):
        """
        we have list data_from_DB[] that consis all source from bases
        when we check dir we need update metadata from source
        :modify self.data_from_DB[]
           """
        self.logger.debug("call modify_data_from_db_buffer()")
        self.logger.debug("{} {} {}".format(position, date, size))
        if isinstance(position, int):
            # print("date=", str(self.data_from_DB[position]["last_date"]))
            if (not self.data_from_DB[position]["last_date"]) or (
                    str(date) > str(self.data_from_DB[position]["last_date"])):
                # print("---")
                self.data_from_DB[position]["last_date"] = date
                self.data_from_DB[position]["last_size"] = size
            self.data_from_DB[position]["count"] = int(self.data_from_DB[position]["count"]) + 1

    def walk_on_files(self):
        """
            walk on list of files
           """
        self.logger.debug("call walk_on_files()")
        self.data_add_log = []
        for file in self.files_list:
            data = self.get_data_from_file(file)
            self.logger.debug("data={0}".format(data))
            id, pos = self.check_in_bases(data)
            self.logger.debug("ret id = {0}, pos={1}".format(id, pos))
            if id < 0:
                id = self.add_backup_to_db_bases(data, file["size"])
                pos = len(self.data_from_DB) - 1  # last element
                self.logger.debug("NEW ID={0}, pos={1}".format(id, pos))
            else:
                self.logger.debug("Exist ID={0}".format(id))

            # add records to buffer log

            self.add_record_to_buffer_log(
                {"id": id, "fullname": file["fname"], "bdate": data["bdate"], "bsize": file["size"]})
            self.modify_data_from_db_buffer(
                position=pos,
                date=data["bdate"],
                size=file["size"]
            )

        # вывожу обновлённый список
        #      for i in range(len(self.data_from_DB)):
        #          print(self.data_from_DB[i])
        if len(self.files_list) > 0:
            self.upgrade_db_bases()  # upgrade Bases
            self.add_record_to_db_log()  # upgrade Log

    @logme
    def print_files_list(self):
        """
            for debug only
           """
        if len(self.files_list) > 0:
            for f in self.files_list:
                # print('file={0}'.format(f))
                ret = self.get_data_from_file(f)
                print(ret)
                # break

    ##************   Work with DATABASES   ************

    def create_db(self):
        """
        Create DB Bases
        Create DB Log
           """
        self.logger.debug("create_db()")
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                with conn.cursor() as cursor:
                    query = "CREATE TABLE bases ( \
                           id        serial NOT NULL primary key, \
                           stand   	   varchar(50) NOT NULL, \
                           bname   	   varchar(100) NOT NULL, \
                           btype   	   varchar(50), \
                           bhost        varchar(50) NOT null, \
                           last_date    date, \
                           last_size  bigint, \
                           count        integer, \
                           need_notification  boolean NOT NULL DEFAUL TRUE);"
                    self.logger.debug("query ={0}".format(query))
                    cursor.execute(query)
                    conn.commit()
                    self.logger.debug("Create table Bases")

                    query = "CREATE TABLE log ( \
                           id           integer NOT NULL, \
                           fullname   	 varchar(150) NOT NULL primary key, \
                           bdate        date, \
                           bsize        bigint);"
                    self.logger.debug("query ={0}".format(query))
                    cursor.execute(query)
                    conn.commit()
                    self.logger.debug("Create table Log")
        except Exception as e:
            self.logger.error("Error create table in Database. {0}".format(e))

    def add_backup_to_db_bases(self, data, size):
        """if source not exist in Bases -> so need to add it to Bases and receive ID
        :return id
           """
        self.logger.debug("add_backup_to_db_bases()")
        ret = None
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                conn.autocommit = True
                with conn.cursor() as cursor:
                    query = "INSERT INTO bases (stand, bname, btype, bhost) VALUES ('{0}', '{1}', '{2}', '{3}')".format(
                        data["stand"],
                        data["bname"],
                        data["btype"],
                        self.hostname
                    )
                    self.logger.debug("query ={0}".format(query))
                    cursor.execute(query)
                    # conn.commit()
                    self.logger.info("Add backup source to Bases. Backup={0}_{1}_{2}".format(
                        data["stand"],
                        data["bname"],
                        data["btype"]))

                    query = "SELECT * FROM bases WHERE stand='{0}' and bname='{1}' and btype='{2}' and bhost='{3}'".format(
                        data["stand"],
                        data["bname"],
                        data["btype"],
                        self.hostname
                    )
                    self.logger.debug("query ={0}".format(query))
                    cursor.execute(query)

                    if cursor.rowcount > 0:
                        for row in cursor:
                            ret = self.add_to_data_from_DB(row)
                    else:
                        self.logger.debug("no data from DB Bases")

        except Exception as e:
            self.logger.error("Error insert data to Database. {0}".format(e))
        return ret

    def add_record_to_db_log(self):
        """add row with new file to db LOG
        dublicate doesn't add
        filename - primary key
           """
        self.logger.debug("add_record_to_db_log()")
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                conn.autocommit = True
                with conn.cursor() as cursor:
                    #print(self.data_add_log)
                    if len(self.data_add_log) > 0:
                        for record in self.data_add_log:
                            query = "INSERT INTO log (id, fullname, bdate, bsize) VALUES ({0}, '{1}', '{2}', {3})".format(
                                record["id"],
                                record["fullname"],
                                record["bdate"],
                                record["bsize"]
                            )
                            self.logger.debug("query ={0}".format(query))
                            try:
                                cursor.execute(query)
                            except Exception as e:
                                self.logger.error("Error insert {1} to Log. {0}".format(e, record["fullname"]))
                        # conn.commit()
                        # cursor.execute(query, [data["stand"], data["bname"], data["btype"], str(self.hostname)])
                        self.logger.info("Add row to log. Filename={0}".format(record["fullname"]))
        except Exception as e:
            self.logger.error("Error insert data to Database. {0}".format(e))

    def upgrade_db_bases(self):
        """
        when checked all dir and form local buffer list with source
        we need update metabata in DB Bases
           """
        self.logger.debug("upgrade_db_bases()")
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                with conn.cursor() as cursor:
                    for record in self.data_from_DB:
                        query = "UPDATE bases SET last_date='{0}', last_size={1}, count={2} WHERE id={3}".format(
                            record["last_date"],
                            record["last_size"],
                            record["count"],
                            record["id"]
                        )
                        self.logger.debug("query ={0}".format(query))
                        try:
                            self.logger.info("Update Bases metadata row[id] ={0}".format(record["id"]))
                            cursor.execute(query)
                        except Exception as e:
                            self.logger.error("Error insert {1} to Log. {0}".format(e, record["fullname"]))
                    conn.commit()
        except Exception as e:
            self.logger.error("Error insert data to Database. {0}".format(e))

    @logme
    def check_db(self):
        """
            check exist bases.
            Not finished
           """
        self.logger.debug("call check_db()")
        ret = None
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                with conn.cursor() as cursor:
                    query = "SELECT * FROM information_schema.tables WHERE table_schema = 'public'"
                    self.logger.debug("checkdb[query]:{0}.".format(query))
                    cursor.execute(query)
                    if cursor.rowcount > 0:
                        ret = cursor.rowcount
                    else:
                        print("No table -> create")
                        self.logger.error("Tables don't exist!")
        except Exception as e:
            self.logger.error("Error get data from Database. {0}".format(e))
        return ret

    @logme
    def get_data_from_db(self):
        """
        first function to get data from Bases about source (list exist backups)
           """
        self.logger.debug("call get_data_from_db()")
        self.data_from_DB = []
        ret = None
        try:
            with closing(psycopg2.connect(
                    dbname=self.db_name,
                    user=self.db_user,
                    password=self.db_pass,
                    host=self.db_host,
                    connect_timeout=3
            )) as conn:
                with conn.cursor() as cursor:
                    query = "SELECT * FROM bases"
                    self.logger.debug("query ={0}".format(query))
                    cursor.execute(query)
                    if cursor.rowcount > 0:
                        for row in cursor:
                            self.add_to_data_from_DB(row)  # append list
                    else:
                        self.logger.debug("No data from Bases -> create")
        except Exception as e:
            self.logger.error("Error get data from Database. {0}".format(e))
        return ret

    def print_data_from_db(self):
        """
               for test
        """
        print("Data from Bases:")
        for i in self.data_from_DB:
            print(i)

    def analize_for_telegram(self):
        """
               form message[] for telegram
        """
        now = datetime.date.today()
        #print(now)

        list_to_send_alarm = []
        if len(self.data_from_DB) > 0:
            print(self.data_from_DB[0])
            for i in self.data_from_DB:
                if i['need_notification']:

                    date_time_obj = datetime.datetime.strptime(str(i['last_date']), '%Y-%m-%d')
                    timedelta = now - date_time_obj.date()

                    message = ''
                    if timedelta.days >= self.setpoint_days:
                        message = message + 'Created {0} days ago!\t'.format(timedelta)
                    elif i['count'] < self.setpoint_count:
                        message = message + 'Small count of archives = {0}!\t'.format(i['count'])
                    elif i['last_size'] < self.setpoint_size:
                        message = message + 'Archive small size={0:.4f}Mb!'.format(int(i['last_size'])/1048576)
                    if not self.notify_only_alarms and len(message) < 1:
                        message = 'OK'

                    if len(message) > 1:  # have alarms
                        list_to_send_alarm.append(
                            "{0}/{1}/{2}/{3} - {4}".format(i['bhost'], i['stand'], i['btype'], i['bname'],
                                                           message))

        return list_to_send_alarm

    def analize_for_email(self):
        """
               form html with table for email
        """
        now = datetime.date.today()

        message = """\
        <html>
          <head>
           <style>
                .RED_BG { 
                font-size: 120%; 
                font-family: Verdana, Arial, Helvetica, sans-serif; 
                background-color: rgb(255,0,0); 
                }

                .GRAY_BG { 
                font-size: 120%; 
                font-family: Verdana, Arial, Helvetica, sans-serif; 
                background-color: rgb(100,100,100); 
               }
                .tall-row td { 
                height: 20px; 
                width: 100px;
                text-align: center;
               }
          </style>
          </head>
          <body>
            <p>

        """
        message += "Backup report at host:{0}, on date: {1}</p><p>".format(self.hostname, now)
        if len(self.data_from_DB) > 0:
            message = message + """\

            <table class="tall-row">
            <tr class="GRAY_BG"><td>Host</td><td>Stand</td><td>Type</td><td>Name</td><td>Last date</td><td>Last size, Mb</td><td>Count</td></tr>
            """
            for i in self.data_from_DB:
                row = '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td>'.format(i['bhost'], i['stand'], i['btype'],
                                                                                    i['bname'])

                date_time_obj = datetime.datetime.strptime(str(i['last_date']), '%Y-%m-%d')
                timedelta = now - date_time_obj.date()

                style = ' class="RED_BG"' if timedelta.days >= self.setpoint_days else ''
                row = row + '<td{0}>{1}</td>'.format(style, i['last_date'])

                style = ' class="RED_BG"' if i['last_size'] < self.setpoint_size else ''
                row = row + '<td{0}>{1:.4f}</td>'.format(style, int(i['last_size'])/1048576)

                style = ' class="RED_BG"' if i['count'] < self.setpoint_count else ''
                row = row + '<td{0}>{1}</td>'.format(style, i['count'])
                row = row + '</tr>\n'
                message += row
            message = message + """\
            </table>
            """
        message = message + """\
            </p>
          </body>
        </html>
        """

        return message

    def run(self):
        """
               main function. RUN
        """
        self.logger.debug("run")
        try:
            # 1. Проверяю базы
            if self.check_db():
                self.get_data_from_db()

                self.formFilesList()  # get list of file in dir
                self.walk_on_files()  # walk on file and analyze

            else:
                self.create_db()
        except Exception as e:
            self.logger.error("Common error. {0}".format(e))


if __name__ == '__main__':
    print("This is class file")
