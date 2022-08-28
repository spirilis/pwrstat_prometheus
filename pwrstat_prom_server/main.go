package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"os/exec"
)

// Upon HTTP request, execute "pwrstat -version; pwrstat -status" and process the output through "gawk -f pwrstat-prometheus.awk", returning
// the output in the body of the HTTP response.
func metricsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("Handling a request-")
	pwrstatData := bytes.NewBufferString("")
	prometheusData := bytes.NewBufferString("")

	// run pwrstat -version and capture output
	pwrstatVersionCmd := exec.Command("/usr/sbin/pwrstat", "-version")
	stdout, err := pwrstatVersionCmd.StdoutPipe()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	log.Println("Starting pwrstat -version")
	if err := pwrstatVersionCmd.Start(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	d, err := io.ReadAll(stdout) // capture output
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	if err := pwrstatVersionCmd.Wait(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	pwrstatData.Write(d) // store output in a local buffer

	// run pwrstat -status and capture output
	pwrstatStatusCmd := exec.Command("/usr/sbin/pwrstat", "-status")
	stdout, err = pwrstatStatusCmd.StdoutPipe()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	log.Println("Starting pwrstat -status")
	if err = pwrstatStatusCmd.Start(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	d, err = io.ReadAll(stdout) // capture output
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	if err = pwrstatStatusCmd.Wait(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	pwrstatData.Write(d) // store output

	// pwrstatData now contains output of pwrstat -version and pwrstat -status, pipe it to the awk script
	// & scavenge the data to stream to the HTTP client

	gawk := exec.Command("/usr/bin/gawk", "-f", "/usr/local/bin/pwrstat-prometheus.awk")
	stdin, err := gawk.StdinPipe()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	stdout, err = gawk.StdoutPipe()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	log.Println("Starting gawk -f /usr/local/bin/pwrstat-prometheus.awk")
	if err = gawk.Start(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	_, err = pwrstatData.WriteTo(stdin) // pipe output of pwrstat cmds into the gawk script
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	stdin.Close()

	d, err = io.ReadAll(stdout) // and capture the output of the gawk script
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
	prometheusData.Write(d) // store in a temporary buffer

	if err = gawk.Wait(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	// Write prometheusData back to HTTP client

	cLen := fmt.Sprintf("%d", prometheusData.Len())
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Length", cLen)
	w.WriteHeader(http.StatusOK)
	w.Write(prometheusData.Bytes())
}

// Return 200 for readinessProbe purposes
func confirmReady(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func main() {
	http.HandleFunc("/metrics", metricsHandler)
	http.HandleFunc("/", confirmReady)
	http.HandleFunc("/healthz", confirmReady)

	log.Println("Serving on port 9190-")
	log.Fatal(http.ListenAndServe(":9190", nil))
}
