defmodule Topology do

  @errorString "Error: Invalid Input \nValid input: ./project2 numNodes topology algorithm\nTopology: full, 3D, rand2D, line, impLine\nAlgorith: gossip, push-sum"

  def initTopology(numberOfNodes, topology, algorithm) do
    node_list = createNodes(numberOfNodes)

    updateNodesWithNeighbours(topology, node_list, algorithm)

    node_list
  end

  @doc """
  Create nodes on the basis of input.
"""
  def createNodes(numberOfNodes, index \\ 1, node_list \\ [])

  def createNodes(numberOfNodes, index, node_list) when numberOfNodes > 0 do
    {:ok, node_id} = Server.start(index)

    createNodes(numberOfNodes - 1, index + 1, node_list ++ [node_id])
  end

  def createNodes(numberOfNodes, _, node_list) when numberOfNodes == 0 do
    node_list
  end

  @doc """
  Find the neighbours according to the topology and update the nodes accordingly.
"""
  def updateNodesWithNeighbours(topology, node_list, algorithm) do
    case topology do
      "full" -> setupFullTopology(node_list, algorithm)
      "line" -> setupLineTopology(node_list, algorithm)
      "rand2D" -> setupRandom2DGrid(node_list, algorithm)
      "impLine" -> setupImperfectLineTopology(node_list, algorithm)
      "3D" -> setup3DGrid(node_list, algorithm)
      "torus" -> setupTorus(node_list,algorithm)
      _ ->
        IO.puts(@errorString)
        System.halt(0)
    end
  end

  def setupFullTopology(node_list, algorithm) do
    Enum.each(node_list, fn pid ->
      neighbourlist = node_list -- [pid]
      Server.update_neighbours(pid, neighbourlist, algorithm)
    end)
  end

  def setupLineTopology(node_list, algorithm) do
    Enum.each(0..(length(node_list) - 1), fn index ->
      pid = Enum.at(node_list, index)

      neighbourlist =
        cond do
          index == 0 -> [Enum.at(node_list, index + 1)]
          index == length(node_list) - 1 -> [Enum.at(node_list, index - 1)]
          true -> [Enum.at(node_list, index - 1), Enum.at(node_list, index + 1)]
        end

      Server.update_neighbours(pid, neighbourlist, algorithm)
    end)
  end

  def setupRandom2DGrid(node_list, algorithm) do
    map =
      Enum.reduce(node_list, %{}, fn pid, map ->
        x = :rand.uniform(10) / 10
        y = :rand.uniform(10) / 10

        Map.put(map, pid, [x, y])
      end)

    Enum.each(node_list, fn pid ->
      coordinate = map[pid]
      x1 = Enum.at(coordinate, 0)
      y1 = Enum.at(coordinate, 1)

      neighbourlist =
        Enum.filter(node_list -- [pid], fn secondPid ->
          coordinate = map[secondPid]
          x2 = Enum.at(coordinate, 0)
          y2 = Enum.at(coordinate, 1)

          d = :math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)) |> Float.round(1)
          d <= 0.1
        end)

      Server.update_neighbours(pid, neighbourlist, algorithm)
    end)
  end

  def setupImperfectLineTopology(node_list, algorithm) do
    Enum.each(0..(length(node_list) - 1), fn index ->
      pid = Enum.at(node_list, index)

      neighborlist =
        cond do
          index == 0 ->
            neighbourPid = Enum.at(node_list, index + 1)
            otherPid = Enum.random(node_list -- [pid, neighbourPid])
            [neighbourPid, otherPid]

          index == length(node_list) - 1 ->
            neighbourPid = Enum.at(node_list, index - 1)
            otherPid = Enum.random(node_list -- [pid, neighbourPid])
            [neighbourPid, otherPid]

          true ->
            neighbourPids = [Enum.at(node_list, index - 1), Enum.at(node_list, index + 1)]
            otherPid = Enum.random(node_list -- (neighbourPids ++ [pid]))
            [otherPid] ++ neighbourPids
        end

      Server.update_neighbours(pid, neighborlist, algorithm)
    end)
  end

  def setup3DGrid(node_list, algorithm) do
    n = length(node_list)
    dimension = round(:math.ceil(:math.pow(n, 1 / 3)))

    map =
      Enum.reduce(0..(dimension - 1), %{}, fn k, map ->
        Enum.reduce(0..(dimension - 1), map, fn i, map ->
          Enum.reduce(0..(dimension - 1), map, fn j, map ->
            index = i * (dimension * dimension) + j * dimension + k
            node = Enum.at(node_list, index)
            if node != nil, do: Map.put(map, {i, j, k}, node), else: map
          end)
        end)
      end)

    Enum.each(map, fn {{x, y, z}, pid} ->
      neighbourList = Enum.filter(node_list, fn secondPid ->
        (secondPid ==  Map.get(map, {x + 1, y, z}) || secondPid ==  Map.get(map, {x - 1, y, z})
         || secondPid ==  Map.get(map, {x, y + 1, z}) || secondPid ==  Map.get(map, {x, y - 1, z})
         || secondPid ==  Map.get(map, {x, y, z + 1}) || secondPid ==  Map.get(map, {x, y, z + 1}))

      end)
      Server.update_neighbours(pid, neighbourList, algorithm)
    end)
  end

  def setupTorus(node_list, algorithm) do

    n = length(node_list)
    dimension = round(:math.ceil(:math.sqrt(n)))
    grid = Enum.chunk_every(node_list, dimension)

    Enum.each(0..dimension*dimension, fn index ->
      if index < n do
        x = round(:math.floor(index/dimension))
        y = rem(index, dimension);

        left = if y-1 < 0 do y-1 + length(Enum.at(grid, x)) else y-1 end
        right = if y+1 >= length(Enum.at(grid, x)) do y+1 - length(Enum.at(grid, x)) else y+1 end
        top = if x-1 < 0 do x - 1 + length(grid) else x-1 end
        bottom = if x+1 >= length(grid) do x+1-length(grid)  else x+1 end

        topNode    = Enum.at(Enum.at(grid, top), y)
        bottomNode = Enum.at(Enum.at(grid, bottom), y)
        leftNode   = Enum.at(Enum.at(grid, x), left)
        rightNode  = Enum.at(Enum.at(grid, x), right)

        neighbourList = [topNode, bottomNode, leftNode, rightNode]

        #filtering out nil nodes
        neighbourList = Enum.filter(neighbourList, & !is_nil(&1))

        #filter out duplicate nodes
        neighbourList = Enum.uniq(neighbourList)

        pid = Enum.at(Enum.at(grid, x), y)
        Server.update_neighbours(pid, neighbourList, algorithm)
      end
    end)

  end
end
