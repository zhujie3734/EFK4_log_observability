import paramiko
from datetime import datetime
import pytz
import requests

def get_remote_time(host, port,username, password=None, key_path=None):

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy)

    if key_path:
        pkey = paramiko.RSAKey.from_private_key_file(key_path)
        client.connect(hostname=host,port=port,username=username,pkey=pkey)
    else:
        client.connect(hostname=host,port=port,username=username,password=password)

    stdin, stdout, stderr = client.exec_command('date -u +"%Y-%m-%dT%H:%M:%SZ"')
    remote_time_str = stdout.read().decode().strip()
    client.close

    remote_time = datetime.strptime(remote_time_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=pytz.UTC)

    return remote_time

def log(msg,path):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(path, 'a') as f:
        f.write(f"{timestamp} - {msg}\n")

if __name__ == "__main__":

      logpath = r'/etc/prometheus/scripts/get_time_diff.log'

      time1 = get_remote_time("x.x.x.x","22","root",password="xxxx")

      time2 = get_remote_time("x.x.x.x","22","spdblon",password="xxx")

      time_diff = abs((time1 - time2).total_seconds())

      metric_name = "pbx_sbc_time_difference_seconds"

      data = f"""# TYPE {metric_name} gauge
              {metric_name} {time_diff}
             """
      resp = requests.post(
            "http://1.1.1.1:9091/metrics/job/pbx_sbc_time_difference_seconds",
             data=data,
            headers={"Content-Type": "text/plain"}
            )

      if resp.status_code == 200:
         log("Pushed to pushgateway successfully", logpath)
         with open(logpath, 'a') as f:
            print(f"time difference between PBX and SBC is: {time_diff}",file=f)

      else:
         print("Push failed", resp.text)
