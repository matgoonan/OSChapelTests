/**
 * Implements a CPU that runs fake processes.
 *
 * Author: Kyle Burke <https://github.com/paithan>
 * Author: Matheau Goonan <https://github.com/matgoonan>
 */
use Time;
use Random;
use Job;
use BlockingQueue;

//CPU class
class CPU {

    //The incoming queue of Jobs.
    var incoming : BlockingQueue(Job);

    //The domain for the list of completed jobs.  This will grow while we're running the CPU.
    var completedDomain = {0..1};

    //The wait times of completed jobs.
    var waitTimes : [completedDomain] real;

    //The latencies of completed jobs.
    var latencies : [completedDomain] real;

    //The name of the CPU
    var name : string;

    //Whether this is still running.
    var active : bool;

    //The number of jobs that have finished so far.
    var numJobsCompleted : int;

    //Constructor.
    proc CPU(queue: BlockingQueue(Job), name : string) {
        this.incoming = queue;
        this.name = name;
        this.active = true;
        this.numJobsCompleted = 0;
    }

    //runs this CPU.  It will consume Jobs until stop() is called.
    proc start() {
        while (this.active) {
            var job = this.incoming.remove();
            if(this.active) {
                if (this.numJobsCompleted > this.completedDomain.high) {
                    //the completedDomain is too small, so double the size.
                    this.completedDomain = {0..(2*this.numJobsCompleted)};
                }
                job.startRunning();
                //run the job
                sleep(job.getLength());
                //stop the job and record the stats.
                job.stopRunning();
                this.waitTimes[this.numJobsCompleted] = job.getWaitTime();
                this.latencies[this.numJobsCompleted] = job.getLatency();
                writeln("CPU " + this.name + " completed job #", this.numJobsCompleted, ":\n  Wait Time: ", this.waitTimes[this.numJobsCompleted], "s\n  Length: ", job.getLength() + "s\n  Latency: ", this.latencies[this.numJobsCompleted], "s");
                this.numJobsCompleted +=1;
            }
        }
        //reset the size of the completed domain so that it doesn't have a bunch of zeroes at the end.
        //this.completedDomain = {0..(this.numJobsCompleted - 1)};
        //print out the stats
        //writeln(this);
        //writeln(this.incoming);
    }

    //Shuts down the CPU.
    proc stop() {
        this.active = false;
        this.incoming.add(new Job(1));
    }

    //Returns the name.
    proc getName() : string {
        return this.name;
    }

    //Returns whether this is still running.
    proc isActive() : bool {
        return this.active;
    }

    //Returns the total wait time of all jobs processed.
    proc totalWaitTime() : real {
        return + reduce this.waitTimes;
    }

    //Returns the maximum waiting time of all processed jobs.
    proc maxWaitTime() : real {
        return max reduce this.waitTimes;
    }

    //Returns the total latency of all jobs processed.
    proc totalLatency() : real {
        return + reduce this.latencies;
    }

    //Returns the maximum latency of all processed jobs.
    proc maxLatency() : real {
        return max reduce this.latencies;
    }

    //Returns the average wait time of all processed jobs.
    proc averageWaitTime() : real {
        return this.totalWaitTime() / (this.completedDomain.high + 1);
    }

    //Returns the average latency of all processed jobs.
    proc averageLatency() : real {
        return this.totalLatency() / (this.completedDomain.high + 1);
    }

    //writeThis method.  Only prints out the averages when it's finished running
    proc writeThis(writer) {
        writer.writeln("+----- CPU " + this.name + " --------------------------+");
        writer.writeln("| Jobs Completed: ", this.numJobsCompleted);
        writer.writeln("| Total Wait Time: ", this.totalWaitTime());
        writer.writeln("| Total Latency: " + this.totalLatency());
        if (this.active) {
            writer.writeln("| CPU is still running, so averages are not yet calculated.");
        } else {
            writer.writeln("| Average Wait Time: " + this.averageWaitTime());
            writer.writeln("| Average Latency: " + this.averageLatency());
        }
        writer.writeln("| Max Wait Time: " + this.maxWaitTime());
        writer.writeln("| Max Latency: " + this.maxLatency());
        writer.write("+--------------------------------------+");
    }
} //end of CPU class
