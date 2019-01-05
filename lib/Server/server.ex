defmodule Server do
  use GenServer

  @server Server
  @saturationPoint :math.pow(10, -10)

  def start(index) do
    processName = :"Node#{index}"

    #    // debug: [:trace]
    GenServer.start_link(@server, [index], name: processName)
  end

  def update_neighbours(pid, neighbour_list, algorithm) do
    GenServer.call(pid, {:update_neighbour, neighbour_list, algorithm})
  end

  def spreadRumour(pid, rumour, parent) do
    GenServer.cast(pid, {:spread_rumour, rumour, parent})
  end

  def startPushSum(pid, sum, weight, parent) do
    GenServer.cast(pid, {:push_sum, sum, weight, parent})
  end

  def init(neighbour_data) do
    {:ok, neighbour_data}
  end

  def handle_cast({:spread_rumour, rumour, parent}, neighbour_data) do
    {counter, neighbour_list} = neighbour_data

    if neighbour_list != nil do
      randomIndex = Enum.random(0..length(neighbour_list)-1)
      randomNode = Enum.at(neighbour_list, randomIndex)

      if counter <= 10 do
        Server.spreadRumour(randomNode, rumour, parent)
        Server.spreadRumour(self(), rumour, parent)
        else
      end
    end

    if counter == 0 do
      send(parent, {:acknowledgement, self()})
    end

    newState = {counter + 1, neighbour_list}

    {:noreply, newState}
  end

  def handle_cast({:push_sum, sum, weight, parent}, neighbour_data) do
    {counter, currentSum, currentWeight, neighbour_list} = neighbour_data

    currentSumEstimate = currentSum / currentWeight

    newSum = currentSum + sum
    newWeight = currentWeight + weight
    newSumEstimate = newSum / newWeight

    difference = :math.pow(newSumEstimate - currentSumEstimate, 2) |> :math.sqrt()

    counter = if difference < @saturationPoint, do: counter + 1, else: 0

    if counter == 3 do
      send(parent, {:terminating, newSumEstimate, self()})
      send(self(), :kill)
    else
      if neighbour_list != nil do
        randomIndex = Enum.random(0..length(neighbour_list)-1)
        randomNode = Enum.at(neighbour_list, randomIndex)
        Server.startPushSum(randomNode, newSum / 2, newWeight / 2, parent)
      end
    end

    newState = {counter, newSum / 2, newWeight / 2, neighbour_list}

    {:noreply, newState}
  end

  def handle_call({:update_neighbour, neighbour_list, algorithm}, _from, notificationData) do
    case algorithm do
      "gossip" ->
        state = {0, neighbour_list}
        {:reply, "Updating", state}

      "push-sum" ->
        state = {0, Enum.at(notificationData, 0), 1, neighbour_list}
        {:reply, "Updating", state}

      _ ->
        {:reply, "Unavailable", []}
    end
  end

  def handle_info(:kill, state) do
    {:stop, :normal, state}
  end

  def terminate(_, _) do
#        IO.puts("Terminating #{inspect self()}")
  end

  def format_status(_reason, [_pdict, state]) do
    [data: [{'State', "Current state is '#{inspect(state)}'"}]]
  end
end
