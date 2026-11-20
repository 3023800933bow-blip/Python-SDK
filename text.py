# def bow():
#     return 20,30
# x,y=bow()
# print(x,y)





try:
    a = int(input("输入数字："))
    print(10 / a)
except ValueError :
    print("你输入的不是整数！")
except ZeroDivisionError as err:
    print("不能除以0，错误详情：", err)
else:
    print("运行正常，没有异常")
finally:
    print("这句一定会打印")
