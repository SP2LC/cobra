# -*- coding: utf-8 -*-
# Python版画像認識
# MatPlotLib、PILとNumPyが必要
# コマンドライン引数にファイル名を与えて使う。
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import sys
import re
import math
import itertools
import binascii

# 画像を分割する
def split(img, columns, rows):
  images = []
  # shapeで画像サイズを取れるが、[高さ, 幅, 3]の順番になっているので注意
  fullWidth = img.shape[1]
  fullHeight = img.shape[0]
  splitWidth = fullWidth / columns
  splitHeight = fullHeight / rows
  for i in range(columns):
    column = []
    for j in range(rows):
      left = splitWidth * i
      right = left + splitWidth
      top = splitHeight * j
      bottom = top + splitHeight
      # 画像を切り出す
      # これは画像をコピーしないため高速
      # ただし、切り出した画像に書き込むと元画像にも書き込まれるので注意
      # [y, x] の順番なので注意
      splitImage = img[top:bottom, left:right]
      column.append(splitImage)
    images.append(column)
  return images

# 画像をソートする。tableはimgBからimgAを検索する逆引き辞書。
# worstは、一番下にくる画像の座標のリスト。
def sortImages(table, cols, rows, worst):
  sortedImages = []
  usedImgs = {}
  for bottomNum, dummy in worst:
    column = list(range(rows))
    nowImage = bottomNum
    usedImgs[nowImage] = True
    column[rows - 1] = nowImage
    for i in range(rows - 2, -1, -1):
      def notUsed(a):
        return not a[0] in usedImgs
      nowImage = filter(notUsed, table[nowImage])[0][0]
      usedImgs[nowImage] = True
      column[i] = nowImage
    sortedImages.append(column)
  return sortedImages

# 色を比較する
def compareColor(a, b):
  # 各要素の差の二乗は簡単に書ける。
  # -や*は、配列の各要素それぞれに対して実行される。
  # np.sumで合計を求める。
  return math.sqrt(np.sum((a-b)*(a-b)))

# 画像の辺を比較する
# flag=Trueの場合、aの右にbを置く
# flag=Falseの場合、aの下にbを置く
def compare(imgA, imgB, flag):
  width = imgA.shape[1]
  height = imgA.shape[0]
  if flag:
    # 横に比較する場合
    lineA = imgA[0:height, width - 1]
    lineB = imgB[0:height, 0]
  else:
    # 縦に比較する場合
    lineA = imgA[height - 1, 0:width]
    lineB = imgB[0, 0:width]
  #difference = 0.0
  #for i in range(len(lineA)):
  #  difference += compareColor(lineA[i], lineB[i])
  difference = np.sum(np.sqrt(np.sum((lineA-lineB)*(lineA-lineB), axis=1)))
  return difference / len(lineA)

if len(sys.argv) != 2:
  print "引数が間違っておるぞ!"
  sys.exit(1)

# 分割数の読み込み
# 100という数字は決め打ち!すばらしい!
ppmFile = open(sys.argv[1], "rb").read(100)
splitStrings = re.split("[\t\r\n ]+", ppmFile)
splitColumns = int(splitStrings[2]) # 横の分割数
splitRows = int(splitStrings[3]) # 縦の分割数

# 画像の読み込み
# 上下逆で読まれるので、flipud関数で上下を反転させる
# 環境によっては必要ない？python2.7.6
#img = np.flipud(mpimg.imread(sys.argv[1]))
img = mpimg.imread(sys.argv[1])
# 画像を分割する
splitImages = split(img, splitColumns, splitRows)

resultAToB = {}
resultAToBWidth = {}
# こうすることで、4重ループを簡単に書ける。
for imgANum in itertools.product(range(splitColumns), range(splitRows)):
  print "imgA=(%d, %d)" % imgANum
  resultsHeight = []
  resultsWidth = []
  for imgBNum in itertools.product(range(splitColumns), range(splitRows)):
    if imgANum == imgBNum:
      continue
    imgA = splitImages[imgANum[0]][imgANum[1]]
    imgB = splitImages[imgBNum[0]][imgBNum[1]]
    differenceHeight = compare(imgA, imgB, False)
    differenceWidth = compare(imgA, imgB, True)

    resultsHeight.append((imgBNum, differenceHeight))
    resultsWidth.append((imgBNum,differenceWidth))
  resultAToB[imgANum] = sorted(resultsHeight, key=lambda a: a[1])
  resultAToBWidth[imgANum] = sorted(resultsWidth,key = lambda a: a[1])

  print "H  imgB=%s" % ["%s %f" % a for a in resultAToB[imgANum][0:3]]
  print "W  imgB=%s" % ["%s %f" % a for a in resultAToBWidth[imgANum][0:3]]

def sortWorst(dic):
  minItems = {}
  for k, v in dic.items():
    minValue = min(v, key=lambda a: a[1])
    minItems[k] = minValue[1]
  return sorted(minItems.items(), key=lambda a: a[1])

# 一番下になる画像を探す
# ワーストsplitColumnsを取る
worst = sortWorst(resultAToBWidth)[-splitRows:]
print "worst %d images" % splitRows
for k, v in worst:
  print "%s %f" % (k, v)
# 逆引きリストを作る
worstImgNums = [imgNum for imgNum, v in worst]
resultBToA = {}
resultBToAWidth = {}

for k, v in resultAToBWidth.items():
  for candicate in v:
    if not k in worstImgNums:
      if not candicate[0] in resultBToAWidth:
        resultBToAWidth[candicate[0]] = []
      resultBToAWidth[candicate[0]].append((k, candicate[1]))
      resultBToAWidth[candicate[0]].sort(key=lambda a: a[1])

sortedImages = sortImages(resultBToAWidth, splitRows, splitColumns, worst)
print sortedImages

newImg = np.hstack(
  [np.vstack([splitImages[a[0]][a[1]] for a in row])
    for row in np.array(sortedImages).transpose((1, 0, 2))]
)

plt.imshow(newImg)
plt.show()#ここまで画像認識

#tupleを格納した2次元配列を１６進数変数を不膣確認した2次元配列に変換
def tupleToHex(tupleMatrix,N,M):
  Matrix = [[0 for j in range(M)] for i in range(N)]
  for i in range(len(tupleMatrix)):
    for j in range(len(tupleMatrix[i])):
      Matrix[i][j]=sortedImages[i][j][1]+sortedImages[i][j][0]*16
  return Matrix


#二次元配列表示関数
def printDoubleMatrix(Matrix):
    print ("↓")
    for i in range(N):
        for j in range(M):
            print "%02X" %(Matrix[i][j])," ",
        print ("")

#パズル関数
#左移動・上移動
def changeMatrixLeftDown(x,y,nowi,nowj):
    global SumChangeCount
    for i in range (x):
        print "Left Change Matrix","%02X" %(MatrixFalse[nowi][nowj - i]),"and","%02X" %(MatrixFalse[nowi][nowj - i - 1])
        temp = MatrixFalse[nowi][nowj - i]
        MatrixFalse[nowi][nowj - i] = MatrixFalse[nowi][nowj - i - 1]
        MatrixFalse[nowi][nowj - i - 1] = temp
        printDoubleMatrix(MatrixFalse)
        SumChangeCount = SumChangeCount + 1
        Ans.append("L")  
        
    for j in range (y):
        print "Up Change Matrix","%02X" %(MatrixFalse[nowi - j][nowj - i - 1]),"and","%02X" %(MatrixFalse[nowi - j - 1][nowj - i - 1])
        temp = MatrixFalse[nowi - j][nowj - i - 1]
        MatrixFalse[nowi - j][nowj - i - 1] = MatrixFalse[nowi - j - 1 ][nowj - i - 1]
        MatrixFalse[nowi - j - 1][nowj - i - 1] = temp
        printDoubleMatrix(MatrixFalse)
        SumChangeCount = SumChangeCount + 1
        Ans.append("U")

#右移動・上移動        
def changeMatrixRightDown(x,y,nowi,nowj):
    global SumChangeCount
    for i in range (x):
        print "Right Change Matrix","%02X" %(MatrixFalse[nowi][nowj + i]),"and","%02X" %(MatrixFalse[nowi][nowj + i + 1])
        temp = MatrixFalse[nowi][nowj + i]
        MatrixFalse[nowi][nowj + i] = MatrixFalse[nowi][nowj + i + 1]
        MatrixFalse[nowi][nowj + i + 1] = temp
        printDoubleMatrix(MatrixFalse)
        SumChangeCount = SumChangeCount + 1
        Ans.append("R")
        
    for j in range (y):
        print "Up Change Matrix","%02X" %(MatrixFalse[nowi - j][nowj + i]),"and","%02X" %(MatrixFalse[nowi - j - 1][nowj + i + 1])
        temp = MatrixFalse[nowi - j][nowj + i + 1]
        MatrixFalse[nowi - j][nowj + i + 1] = MatrixFalse[nowi - j - 1 ][nowj + i + 1]
        MatrixFalse[nowi - j - 1][nowj + i + 1] = temp
        printDoubleMatrix(MatrixFalse)
        SumChangeCount = SumChangeCount + 1
        Ans.append("U")

#上移動のみ    
def changeMatrixDown(x,nowi,nowj):
    global SumChangeCount
    for i in range (x):
        print "UpOnly Change Matrix","%02X" %(MatrixFalse[nowi - i][nowj]),"and","%02X" %(MatrixFalse[nowi - i - 1][nowj])
        temp = MatrixFalse[nowi - i][nowj]
        MatrixFalse[nowi - i][nowj] = MatrixFalse[nowi - i - 1][nowj]
        MatrixFalse[nowi - i - 1][nowj] = temp
        printDoubleMatrix(MatrixFalse)
        SumChangeCount = SumChangeCount + 1
        Ans.append("U")




#真(正解画像)の二次元配列の初期化
N = len(sortedImages)
M = len(sortedImages[0])

MatrixTure = tupleToHex(sortedImages,N,M)
#偽(問題画像)の二次元配列の初期化
MatrixFalse = [[0 for j in range(M)] for i in range(N)]

#カウント系
SumChangeCount = 0
SumSelectCount = 0
StackChange = []
count = 0
Ans = []


#main文
#アルゴリズムでは要素の比較をしていないので、中身の数字に影響はない
#真の二次元配列への番号の割り当て
printDoubleMatrix(MatrixTure)

#偽の二次元配列への番号の割り当て
for i in range(N):
    for j in range(M):
        MatrixFalse[i][j] = i + j * 16
print ("FirstMatrixFalse")
printDoubleMatrix(MatrixFalse)

                             
#真==偽の探索(O(N^4)!?)
for i in range (N):
    for j in range (M):

        for k in range(N):
            for l in range(M):
                if MatrixTure[i][j] == MatrixFalse[k][l]:
                    
                    
                    count = SumChangeCount
                    width = j - l
                    height = i - k
                    if (width < 0):
                        changeMatrixLeftDown(-width,-height,k,l)
                    if (width > 0):
                        changeMatrixRightDown(width,-height,k,l)
                    if (width == 0):
                        changeMatrixDown(-height,k,l)
                    if (width == 0) and (height == 0):
                        print "not change","%02X" % MatrixTure[i][j]
                        break
                    SumSelectCount = SumSelectCount + 1
                    count = SumChangeCount - count
                    Ans.insert(-count,"%02X" % MatrixTure[i][j])
                    Ans.insert(-count,count)
                    print "NEXT!!"


#選択回数と交換回数の表示
print "Sum Select Count = ",SumSelectCount,"Sum Change Count = ",SumChangeCount
#公式回答
Ans.insert(0,SumSelectCount)
print "Ans", Ans

