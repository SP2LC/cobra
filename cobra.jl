using ImageView, Images
require("a_star.jl")
require("communication.jl")

VERSION = "Julia"
TO_COMMUNICATION = true # trueなら自前鯖、falseならProconSimpleServer at localhost
NO_POST = false

function minBy(arr; by=x->x)
  minimumElem = nothing
  minimumValue = nothing
  for a in arr
    key = by(a)
    if minimumValue == nothing || key < minimumValue
      minimumElem = a
      minimumValue = key
    end
  end
  return minimumElem
end

function split(img::Image, columns::Int, rows::Int)
  images = Array(Array{Uint8, 3}, (columns, rows))
  fullWidth = size(img)[2]
  fullHeight = size(img)[3]
  splitWidth = iround(fullWidth / columns)
  splitHeight = iround(fullHeight / rows)
  
  for i in 1:columns, j in 1:rows
    left = splitWidth * (i - 1) + 1
    right = left + splitWidth - 1
    top = splitHeight * (j - 1) + 1
    bottom = top + splitHeight - 1
    # 画像を切り出す
    println((left, right, top, bottom))
    splitImage = img[1:3, left:right, top:bottom]
    images[i, j] = splitImage
  end
  return images
end

function compare(imgA, imgB, flag)
  width = size(imgA)[2]
  height = size(imgB)[3]
  diff = 0
  imgA = uint8(imgA)
  imgB = uint8(imgB)
  if flag
    lst = int64(squeeze(map(x -> uint8(x^2), imgA[:, width, :] - imgB[:, 1, :]), 2))
    diff = sum(sqrt(sum(lst, 1))) / height
  else
    lst = int64(squeeze(map(x -> uint8(x^2), imgA[:, :, height] - imgB[:, :, 1]), 3))
    diff = sum(sqrt(sum(int64(lst), 1))) / width
  end
  return diff
end

function findRightBottom(resultW, resultH)
  lst = ((Int, Int), Float64)[]
  for k in keys(resultW)
    v = resultW[k]
    minValueW = minBy(v, by=a->a[2])[2]
    minValueH = minBy(resultH[k], by=a->a[2])[2]
    push!(lst, (k, minValueW * minValueH))
  end
  sort!(lst, by= a -> a[2])
  reverse!(lst)
  return lst
end

function getNeighbours(x, y, array)
  width, height = size(array)
  result = Array(Any, 4)
  fill!(result, -1)
  if x - 1 >= 1
    result[1] = array[x - 1, y]
  end
  if x + 1 <= width
    result[2] = array[x + 1, y]
  end
  if y - 1 >= 1
    result[3] = array[x, y - 1]
  end
  if y + 1 <= height
    result[4] = array[x, y + 1]
  end
  return result
end

function sortImages2(resultAToBWidth, resultBToAWidth, resultAToBHeight, resultBToAHeight, startList, array)
  vals = Array(Float64, (splitColumns, splitRows))
  width, height = size(array)
  tables = (resultAToBWidth, resultBToAWidth, resultAToBHeight, resultBToAHeight)
  queue = Any[]
  # 初期値を入れておく
  for (pos, img, value) in startList
    array[pos[1], pos[2]] = img
    vals[pos[1], pos[2]] = value
    unshift!(queue, pos)
  end
  # 組み立てる
  while length(queue) != 0
    x, y = pop!(queue)
    thisImg = array[x, y]
    neighbours = getNeighbours(x, y, array)
    neighboursPosX = [x - 1, x + 1, x, x]
    neighboursPosY = [y, y, y - 1, y + 1]
    for (i, neighbour) in zip(1:length(neighbours), neighbours)
      if neighbour == -1
        continue
      end
      nextNeighbours = getNeighbours(neighboursPosX[i], neighboursPosY[i], array)
      nextNeighboursPosX = map(a -> a + neighboursPosX[i], [-1, 1, 0, 0])
      nextNeighboursPosY = map(a -> a + neighboursPosY[i], [0, 0, -1, 1])
      newImgs = Array(Any, 0)
      for (j, img) in zip(1:length(nextNeighbours), nextNeighbours)
        if img != -1 && img != nothing
          newImg = tables[j][img][1]
          push!(newImgs, (vals[nextNeighboursPosX[j], nextNeighboursPosY[j]], newImg))
        end
      end
      if length(newImgs) != 0
        nextImg = minBy(newImgs, by=a -> a[2][2])
        newValue = nextImg[1]
        if array[neighboursPosX[i], neighboursPosY[i]] == nothing || vals[neighboursPosX[i], neighboursPosY[i]] > newValue
          if vals[neighboursPosX[i], neighboursPosY[i]] > newValue
            @printf("rewrite %s to %s", vals[neighboursPosX[i], neighboursPosY[i]], newValue)
          end
          array[neighboursPosX[i], neighboursPosY[i]] = nextImg[2][1]
          vals[neighboursPosX[i], neighboursPosY[i]] = newValue
          unshift!(queue, (neighboursPosX[i], neighboursPosY[i]))
        end
      end
    end
  end
  println("values----")
  println(vals)
end

function loadImage(probid)
  run(`wget "http://sp2lc.salesio-sp.ac.jp/procon.php?probID=$(probid)" -O /tmp/cobra-prob.ppm`)
  f = open("/tmp/cobra-prob.ppm", "r")
  ppmfile_content = readbytes(f, 200)
  close(f)
#ppmfile_content = convert(Array{Uint8, 1}, get_problem("5", TO_COMMUNICATION))
  ppmfile = ppmfile_content[1:100]
  splitStrings = Base.split(bytestring(ppmfile), r"[\t\r\n ]+")
  splitColumns = int(splitStrings[3])
  splitRows = int(splitStrings[4])
  LIMIT_SELECTION = int(splitStrings[6])
  SELECTION_RATE = int(splitStrings[8])
  EXCHANGE_RATE = int(splitStrings[9])
  println(splitColumns)
  println(splitRows)
  println(LIMIT_SELECTION)
  println(SELECTION_RATE)
  println(EXCHANGE_RATE)

  img = int64(imread("/tmp/cobra-prob.ppm"))
#strm = IOStream("hoge.ppm", ppmfile_content)
#img = imread(strm, Images.PPMBinary)
  return (img, splitColumns, splitRows, LIMIT_SELECTION, SELECTION_RATE, EXCHANGE_RATE)
end

function calculate(splitImages, splitColumns, splitRows)
  resultAToBHeight = Dict()
  resultAToBWidth = Dict()
  for i in 1:splitColumns, j in 1:splitRows
    @printf("imgA=(%d, %d)\n", i, j)
    imgANum = (i, j)
    resultsHeight = ((Int, Int), Float64)[]
    resultsWidth = ((Int, Int), Float64)[]
    for k in 1:splitColumns, l in 1:splitRows
      #@printf("imgB=(%d, %d)\n", k, l)
      imgBNum = (k, l)
      if imgANum == imgBNum
        continue
      end
      imgA = splitImages[imgANum[1], imgANum[2]]
      imgB = splitImages[imgBNum[1], imgBNum[2]]
      differenceHeight = compare(imgA, imgB, false)
      differenceWidth = compare(imgA, imgB, true)
      push!(resultsHeight, (imgBNum, differenceHeight))
      push!(resultsWidth, (imgBNum, differenceWidth))
    end
    sort!(resultsHeight, by=a->a[2])
    sort!(resultsWidth, by=a->a[2])
    println("H")
    println(resultsHeight[1:4])
    println("W")
    println(resultsWidth[1:4])
    resultAToBHeight[imgANum] = resultsHeight
    resultAToBWidth[imgANum] = resultsWidth
  end
# 逆引きリストを作る
  resultBToAHeight = Dict()
  resultBToAWidth = Dict()

  for k in keys(resultAToBWidth)
    v = resultAToBWidth[k]
    for candicate in v
      if !(haskey(resultBToAWidth, candicate[1]))
        resultBToAWidth[candicate[1]] = Array(((Int, Int), Float64), 0)
      end
      push!(resultBToAWidth[candicate[1]], (k, candicate[2]))
      sort!(resultBToAWidth[candicate[1]], by=a->a[2])
    end
  end

  for k in keys(resultAToBHeight)
    v = resultAToBHeight[k]
    for candicate in v
      if !(haskey(resultBToAHeight, candicate[1]))
        resultBToAHeight[candicate[1]] = Array(((Int, Int), Float64), 0)
      end
      push!(resultBToAHeight[candicate[1]], (k, candicate[2]))
      sort!(resultBToAHeight[candicate[1]], by=a->a[2])
    end
  end

  return (resultAToBWidth, resultAToBHeight, resultBToAWidth, resultBToAHeight)
end

function connectImages(imgs, splitColumns, splitRows)
  colors, widt, heig = size(imgs[1, 1])
  print((widt, heig))
  newImg = Array(Uint8, (3, 0, heig * splitRows))
  for i in 1:splitColumns
    col = Array(Uint8, (3, widt, 0))
    for j in 1:splitRows
      col = cat(3, col, imgs[i, j])
    end
    println(size(newImg))
    println(size(col))
    newImg = cat(2, newImg, col)
  end
  return newImg
end

startTime = time()

# 引数パース
probid = ARGS[1]

img, splitColumns, splitRows, LIMIT_SELECTION, SELECTION_RATE, EXCHANGE_RATE = loadImage(probid)

splitImages = split(img, splitColumns, splitRows)

view(colorim(img))


resultAToBWidth, resultAToBHeight, resultBToAWidth, resultBToAHeight = calculate(splitImages, splitColumns, splitRows)

rightBottom = findRightBottom(resultAToBWidth, resultAToBHeight)
println("右下はこいつだ!")
println(rightBottom[1])
leftBottom = findRightBottom(resultBToAWidth, resultAToBHeight)
println("左下はこいつだ!")
println(leftBottom[1])
leftTop = findRightBottom(resultBToAWidth, resultBToAHeight)
println("左上はこいつだ!")
println(leftTop[1])
rightTop = findRightBottom(resultAToBWidth, resultBToAHeight)
println("右上はこいつだ!")
println(rightTop[1])

sortedImages = Array(Any, (splitColumns, splitRows))
fill!(sortedImages, nothing)  # 妙なデフォルト値が入ってるのでnothingで埋める

startList = [
  ((splitColumns, splitRows), rightBottom[1][1], rightBottom[1][2]),
  ((splitColumns, 1), rightTop[1][1], rightTop[1][2]),
  ((1, splitRows), leftBottom[1][1], leftBottom[1][2]),
  ((1, 1), leftTop[1][1], leftTop[1][2])]

sortImages2(resultAToBWidth, resultBToAWidth, resultAToBHeight, resultBToAHeight, startList, sortedImages)
println(sortedImages)

splitImages2 = map(a -> splitImages[a[1], a[2]], sortedImages)

newImg = connectImages(splitImages2, splitColumns, splitRows)
println(size(newImg))

view(colorim(newImg))

sortedImages0 = map(a -> (a[1] - 1, a[2] - 1), sortedImages)

answer_string=solve(sortedImages0,splitColumns,splitRows,LIMIT_SELECTION,SELECTION_RATE,EXCHANGE_RATE)
runtime = time() - startTime
println(post_answer(answer_string, int(runtime), VERSION, probid,TO_COMMUNICATION))

#readline()
