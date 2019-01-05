defmodule Project2 do
  @moduledoc """
  takes up the arguments from the command line and process the input
  ---Valid local input: ./project1 n k---Valid server input: ./project1 IPAddress n k---Valid client input: ./project1 IPAddress
  """
  @errorString "Error: Invalid Input \nValid input: ./project2 numNodes topology algorithm\nTopology: full, 3D, rand2D, line, impLine\nAlgorith: gossip, push-sum"

  @roumor "Have you heard it?"
  def main(args) do
    with parsedArgs = args |> parse_args() do
      cond do
        length(parsedArgs) == 3 ->
          [numberOfNodes, topology, algorithm] = parsedArgs

          case algorithm do
            "gossip" ->
              node_list = initTopology(numberOfNodes, topology, algorithm)
              startGossip(node_list)

            "push-sum" ->
              node_list = initTopology(numberOfNodes, topology, algorithm)
              startPushSum(node_list)

            _ ->
              IO.puts(@errorString)
              System.halt(0)
          end
      end
    end
  end

  @doc """
  Parse the arguments into the required form
  """
  def parse_args(args) when length(args) != 3 do
    IO.puts(@errorString)

    # stop the program from running
    System.halt(0)
  end

  def parse_args(args) do
    args
    |> args_to_internal_representation()
  end

  defp args_to_internal_representation([numNodes, topology, algorithm]) do
    [toInteger(numNodes), topology, algorithm]
  end

  def toInteger(number) do
    if match?({_, ""}, Integer.parse(number)) do
      value = String.to_integer(number)
      value
    else
      IO.puts(@errorString)
      System.halt(0)
    end
  end

  def receiver(node_list, startTime, acknowledgements \\ []) do
    receive do
      {:acknowledgement, pid} ->
        numberOfNodes = length(node_list)
        acknowledgements = if !Enum.member?(acknowledgements, pid), do: acknowledgements ++ [pid]
        convergence = (length(acknowledgements) * 100 / numberOfNodes) |> :math.ceil() |> round

        if convergence < 90 do
          receiver(node_list, startTime, acknowledgements)
        else

          end_time = (:erlang.system_time() / 1.0e6) |> round
          IO.puts("System converged in #{end_time - startTime} ms")

          Process.exit(self(), :kill)
        end

      {:terminating, newSumEstimate, pid} ->
        numberOfNodes = length(node_list)
        acknowledgements = if !Enum.member?(acknowledgements, pid), do: acknowledgements ++ [pid]

        if length(acknowledgements) == numberOfNodes do
          receiver(node_list, startTime, acknowledgements)
        else
          end_time = (:erlang.system_time() / 1.0e6) |> round
          IO.puts("All nodes converged to the average value #{inspect(newSumEstimate)}")
          IO.puts("System converged in #{end_time - startTime} ms")

          Process.exit(self(), :kill)
        end
    end

    receiver(node_list, startTime, acknowledgements)
  end

  @doc """
  Create the nodes and update the neighbours in order to create the topology
"""
  def initTopology(numberOfNodes, topology, algorithm) do
    node_list = Topology.initTopology(numberOfNodes, topology, algorithm)
    node_list
  end

  @doc """
  Pick the starting node and start the gossip
"""
  def startGossip(node_list) do
    IO.puts("Starting...")

    [headNode | _] = node_list

    Server.spreadRumour(headNode, @roumor, self())

    start_time = (:erlang.system_time() / 1.0e6) |> round
    receiver(node_list, start_time)
  end

  @doc """
  Pick the starting node and push the sum
"""
  def startPushSum(node_list) do
    IO.puts("Starting...")

    [headNode | _] = node_list

    Server.startPushSum(headNode, 0, 0, self())

    start_time = (:erlang.system_time() / 1.0e6) |> round
    receiver(node_list, start_time)
  end

end
