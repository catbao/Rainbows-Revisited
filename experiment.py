import time
import string
import os
import json
import csv
import random

from concurrent.futures import ThreadPoolExecutor

from flask import Flask, request, render_template, redirect, url_for, make_response

app = Flask(__name__)
executor = ThreadPoolExecutor(5)

EXPECTED_PARTICIPANT_NUM = 80

def get_shuffle_order(length):
    l_range = list(range(0, length))
    random.seed(0)
    random.shuffle(l_range)
    return l_range


def append_to_file(filepath, line):
    with open(filepath, 'a') as outfile:
        outfile.write(line+'\n')

def generateRandomCode():
    src_digits = string.digits  # string_数字
    src_uppercase = string.ascii_uppercase  # string_大写字母
    src_lowercase = string.ascii_lowercase  # string_小写字母

    # 随机生成数字、大写字母、小写字母的组成个数（可根据实际需要进行更改）
    digits_num = random.randint(1, 6)
    uppercase_num = random.randint(1, 8-digits_num-1)
    lowercase_num = 8 - (digits_num + uppercase_num)
    # 生成字符串
    password = random.sample(src_digits, digits_num) + random.sample(
        src_uppercase, uppercase_num) + random.sample(src_lowercase, lowercase_num)
    # 打乱字符串
    random.shuffle(password)
    # 列表转字符串
    new_password = ''.join(password)

    return new_password


if(not os.path.exists('results/user_info.csv')):
    executor.submit(append_to_file, 'results/user_info.csv',
                    ','.join(("workerId", "age", "gender", "degree", "screenSize", "familiar", "comment", "code", "startTime", "endTime")))

################################
# Comparing Value task
################################
@app.route('/res', methods=['POST'])
# def write_result_to_disk1():
#     result = json.loads(request.form.get('result'))
#     is_existed = os.path.exists('results/Comparing_value_results.csv')
#     with open('results/Comparing_value_results.csv', 'a') as outfile:
#         if not is_existed:
#             outfile.write(','.join(("blockNum","trialNum","stimulusNum","correct","selection","distance")) + '\n')
#         for trial in result:
#             outfile.write(','.join((request.form.get("blockNum"), trial["trialNum"], trial["stimulusNum"], str(trial["correct"]), str(trial["selection"]), str(trial["distance"]))) + '\n')
#     return url_for('form')
def write_result_to_disk1():  
    # 假设 request.form.get('result') 返回的是上面提供的 JSON 字符串  
    result_json = request.form.get('result')  
    result_data = json.loads(result_json)  # 解析 JSON 字符串为字典  
      
    experimental_data = result_data.get("experimentalData", [])  
    # block_num = result_data.get("blockNum", "")  # 如果还需要写入其他字段，可以从 result_data 中获取  
      
    is_existed = os.path.exists('results/Comparing_value_results.csv')  
    with open('results/Comparing_value_results.csv', 'a', newline='') as outfile:  # 使用 newline='' 避免在 Windows 上的空行问题  
        csv_writer = csv.writer(outfile)   
        if not is_existed:  
            fieldnames = ["blockNum", "trialNum", "stimulusNum", "distance", "correct", "selection"]  
            csv_writer.writerow(fieldnames)  

        for trial in experimental_data:  
            csv_writer.writerow([  
                1,
                trial["blockNum"], 
                trial["trialNum"],  
                trial["stimulusNum"],  
                trial["distance"],  
                trial["correct"],  
                trial["selection"],  
            ])
    return url_for('form')

@app.route('/experiment1')
def experiment1():
    # with open('static/metadata/DensityComparison_positions.json', 'r') as f:
    #     locs = f.read()
    return render_template('exp1.html')

################################
# process functions
################################
@app.route('/user_info', methods=['POST'])
def user_info():
    code = generateRandomCode()
    executor.submit(append_to_file, 'results/user_info.csv',
                    ','.join((str(request.cookies.get('username')), str(request.form['age']), str(request.form['sex']),
                              str(request.form['degree']), str(request.form['screen_size']), str(
                                  request.form['vis_experience']),
                              "\""+str(request.form['comment_additional'])+"\"", str(code), str(request.cookies.get('startTime')), time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()))))
    return render_template('thankyou.html', code=code)

@app.route('/form')
def form():
    return render_template('form.html')


@app.route('/userguide')
def userguide():
    # determine user id by the row number of user_info.csv
    # with open('./results/user_info.csv') as f:
    #     l = f.readlines()
    # userId=len(l)
    # trialOrder=[]

    # with open('./static/metadata/Enhance_density_map_experiment_design.csv', 'r') as f:
    #     reader = csv.DictReader(f)
    #     for row in reader:
    #         # if (int(row['ParticipantID'])-userId)%EXPECTED_PARTICIPANT_NUM == 0:
    #         trialOrder.append({k:row[k] for k in ('M','D','L')})
    # return render_template('./templates/guide.html', userId=userId, trialOrder=json.dumps(trialOrder))
    # return render_template('./experimental-interface/lineup/crowd/exp1.html')
    return render_template('guide.html')

@app.route('/')
def index():
    return redirect(url_for('userguide'))

@app.route('/error')
def error():
    return render_template('noqualified.html')

@app.route('/noqualified', methods=['GET'])
def noqualified():
    return url_for('error')

if __name__ == '__main__':
# 模板更改后立即生效
    app.jinja_env.auto_reload = True
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    app.run(debug=True, host='0.0.0.0') 