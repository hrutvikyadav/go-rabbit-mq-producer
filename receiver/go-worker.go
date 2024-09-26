package main

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func failOnError(err error, msg string) {
  if err != nil {
	log.Panicf("%s: %s", msg, err)
  }
}

func main() {
	// prepare log file
	pid := os.Getpid()
	logFileName := fmt.Sprintf("/home/hrutvik_/pers/rabbit-mq/worker-%d-log.txt", pid)

	// open the log file in append mode; create it if it doesn't exist
	logFile, err := os.OpenFile(logFileName, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	failOnError(err, "Failed to open log file")
	defer logFile.Close()

	// set log output to the log file
	log.SetOutput(logFile)

	// connect to rabbitmq broker
	conn, err := amqp.Dial("amqp://hrutvik:rabbit@localhost:5672/")
	failOnError(err, "Failed to connect to RabbitMQ")
	defer conn.Close()

	// create a channel
	ch, err := conn.Channel()
	failOnError(err, "Failed to open a channel")
	defer ch.Close()

	// declare a queue
	// NOTE: this is idempotent, meaning it will only be created if it doesn't exist already
	q, err := ch.QueueDeclare(
		"durable_task_queue", // name
		true,   // durable
		false,   // delete when unused
		false,   // exclusive
		false,   // no-wait
		nil,     // arguments
	)
	failOnError(err, "Failed to declare a queue")

	err = ch.Qos(
		1,     // prefetch count
		0,     // prefetch size
		false, // global
	)
	failOnError(err, "Failed to set QoS")

	// consume messages from the queue
	msgs, err := ch.Consume(
		q.Name, // queue
		"",     // consumer
		false,   // manual-ack
		false,  // exclusive
		false,  // no-local
		false,  // no-wait
		nil,    // args
	)
	failOnError(err, "Failed to register a consumer")

	// forever channel to keep the program running
	var forever chan struct{}

	go func() {
		for d := range msgs {
			log.Printf("Received a message: %s", d.Body)
			dotCount := bytes.Count(d.Body, []byte("."))
			t:= time.Duration(dotCount)
			time.Sleep(t * time.Second)
			log.Printf("Done")
			d.Ack(false)
		}
	}()

	log.Printf(" [*] Waiting for messages. To exit press CTRL+C")
	<-forever
}
