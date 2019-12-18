using System;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;
using MySql.Data.MySqlClient;

namespace testapp
{
    /// <summary>
/*  
    Local

    One For All Connection Latency: 97ms
    One For All Command Latency: 39ms
    Every one for it self. Connection Latency: 35ms
    Every one for it self Command Latency: 2ms
    Done

   
    One For All Connection Latency: 283ms
    One For All Command Latency: 5072ms
    Every one for it self.Connection Latency: 118689ms
    Every one for it self Command Latency: 6013ms
    Done

    QA
    One For All Connection Latency: 129ms
    One For All Command Latency: 106ms
    Every one for it self. Connection Latency: 1085ms
    Every one for it self Command Latency: 2189ms
    Done

    China:
    One For All Connection Latency: 247ms
    One For All Command Latency: 1326ms
    Every one for it self. Connection Latency: 61004ms
    Every one for it self Command Latency: 1432ms
    Done
*/
    /// </summary>
    class Program
    {
        static void Main(string[] args)
        {
            var iterations = 100;
            var connectionString = Environment.GetEnvironmentVariable("MYSQL_CONNECTION");

            RunTest(iterations, connectionString, connectionPooling: true);
            RunTest(iterations, connectionString, connectionPooling: false);

            Console.WriteLine("Done");
            
        }

        private static void RunTest(int iterations, string connectionString, bool connectionPooling)
        {
            connectionString = connectionString + $";Pooling={connectionPooling}";
            //Console.WriteLine($"Connection Pooling: {connectionPooling}");

            // Warmup

            var wormLatency = WormUp(connectionString);
            Console.WriteLine($"Worm Up Connection with Pooling {(connectionPooling?"Enabled":"Disabled")} Connection Latency: {wormLatency.ConnectionElapsedMilliseconds}ms");
            Console.WriteLine($"Worm Up Connection with Pooling: {(connectionPooling?"Enabled":"Disabled")} Command Latency: {wormLatency.CommandElapsedMilliseconds}ms");
            Console.WriteLine("");
            Console.WriteLine("");

            var coldLatency = ExecutePersisstentConnection(connectionString);
            Console.WriteLine($"Persisstent Connection with Pooling {(connectionPooling?"Enabled":"Disabled")} Connection Latency: {coldLatency.ConnectionElapsedMilliseconds}ms");
            Console.WriteLine($"Persisstent Connection with Pooling: {(connectionPooling?"Enabled":"Disabled")} Command Latency: {coldLatency.CommandElapsedMilliseconds}ms");
            Console.WriteLine("");
            Console.WriteLine("");
            // Average over multiple executions
            var results = new List<Latency>();

            var test = ExecuteNOPersisstentConnection(connectionString);
            Console.WriteLine($"No Persisstent Connection with Pooling: {(connectionPooling?"Enabled":"Disabled")} Connection Latency: {test.ConnectionElapsedMilliseconds}ms");
            Console.WriteLine($"No Persisstent Connection with Pooling: {(connectionPooling?"Enabled":"Disabled")} Command Latency: {test.CommandElapsedMilliseconds}ms");
            Console.WriteLine("");
            Console.WriteLine("");

        }

        private static Latency WormUp(string connectionString)
        {
            var result = new Latency();
            string[] lines = System.IO.File.ReadAllLines(@"connections.sql");

            var stopwatch = new Stopwatch();
            stopwatch.Restart();
            using (var connection = new MySqlConnection(connectionString))
            {
                
                connection.Open();
                result.ConnectionElapsedMilliseconds += stopwatch.ElapsedMilliseconds;
                
                    stopwatch.Restart();
                    using (var command = new MySqlCommand($"select 1", connection))
                    {
                        command.ExecuteScalar();
                        result.CommandElapsedMilliseconds += stopwatch.ElapsedMilliseconds;
                    }
                
            }
            return result;
        }

        private static Latency ExecutePersisstentConnection(string connectionString)
        {
            var result = new Latency();
            string[] lines = System.IO.File.ReadAllLines(@"connections.sql");

            var stopwatch = new Stopwatch();
            stopwatch.Restart();
            using (var connection = new MySqlConnection(connectionString))
            {
                
                connection.Open();
                result.ConnectionElapsedMilliseconds += stopwatch.ElapsedMilliseconds;

               
                foreach (string line in lines)
                {
                    stopwatch.Restart();
                    //Console.WriteLine(line);
                    using (var command = new MySqlCommand($"{line};", connection))
                    {
                        command.ExecuteScalar();
                        result.CommandElapsedMilliseconds += stopwatch.ElapsedMilliseconds;
                    }
                }
            }
            return result;
        }

        private static Latency ExecuteNOPersisstentConnection(string connectionString)
        {
            var result = new Latency();
            string[] lines = System.IO.File.ReadAllLines(@"connections.sql");

            var stopwatch = new Stopwatch();
           
            foreach (string line in lines)
            {
                stopwatch.Restart();
                using (var connection = new MySqlConnection(connectionString))
                {
                    connection.Open();
                    result.ConnectionElapsedMilliseconds += stopwatch.ElapsedMilliseconds;

                    stopwatch.Restart();

                    //Console.WriteLine(line);
                    using (var command = new MySqlCommand($"{line};", connection))
                    {
                        command.ExecuteScalar();
                        result.CommandElapsedMilliseconds += stopwatch.ElapsedMilliseconds;
                    }
                }
            }
            return result;
        }


        class Latency
        {
            public long ConnectionElapsedMilliseconds { get; set; }

            public long CommandElapsedMilliseconds { get; set; }
        }
    }
}
