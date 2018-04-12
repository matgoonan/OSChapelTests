/*******************************
 * Tests Scheduler class.
 *
 * Usage:
 * $ chpl -MteamNameProject2 testScheduler.chpl
 * $ ./testScheduler
 *
 * Inside the folder teamNameProject2 there should be five files:
 * * Semaphore.chpl
 * * BlockingQueue.chpl
 * * Job.chpl (available from https://raw.githubusercontent.com/paithan/OSChapelTests/master/supportClasses/Job.chpl)
 * * CPU.chpl (available from https://raw.githubusercontent.com/paithan/OSChapelTests/master/supportClasses/CPU.chpl)
 * * Scheduler.chpl
 *
 * Author: Kyle Burke <https://github.com/paithan>
 * Author: Matheau Goonan <https://github.com/matgoonan>
 */
use Time;
use Random;
use BlockingQueue;
use Job;
use Scheduler;
use CPU;

//configurable constants
config const n = 100;
config const c = 3;
config const t : real = 3.0;

//better names
var numberJobs = n;
var numCPUs = c;
var maxTime = t;



//number of different tests I'm going to run
var numTests = 3;

var trialsDomain = {0..numTests-1};

var modes : [trialsDomain] string;
modes = ("maximum", "average", "hybrid");

var scoresDomain = {0..6};
var scores : [scoresDomain] int;
scores = (35, 30, 25, 20, 15, 10, 5);

var maxGoals, avgGoals, hybridGoals : [scores.domain] real;
maxGoals = (3.5 * maxTime, 5 * maxTime, 10*maxTime, 13.5*maxTime, 17*maxTime, 20*maxTime, 27*maxTime);
avgGoals = (maxTime, 2*maxTime, 3.5*maxTime, 5*maxTime, 7*maxTime, 8.5*maxTime, 12*maxTime);
hybridGoals = (10*maxTime, 13.5*maxTime, 20*maxTime, 27*maxTime, 33.5*maxTime, 40*maxTime, 50*maxTime);

var things : [0..2, 0..3] real;

//var goals : [scoresDomain] real;
//goals[0] = maxGoals;
//goals[1] = avgGoals;
//goals[2] = hybridGoals;

//var efficiencyGoals : [trialsDomain] real;
//efficiencyGoals = (30.5, 9.5, 50);


var results : TestResult;

for i in trialsDomain {
    var nilResult : TestResult;
    var mode = modes[i];
    writeln("About to run the " + mode + " test.");//  Press Enter to continue.");
    //stdin.readln();
    sleep(2);
    var trialsIndex : int;
    trialsIndex = i;
    //var efficiencyGoal : real;
    //efficiencyGoal = efficiencyGoals[i];
    var xx : int;
    xx = numCPUs;
    var yy : string;
    yy = mode;
    var zz : int;
    zz = numberJobs;
    //runTest(mode, numCPUs, numJobs, efficiencyGoal);

    var newResult = runTest(numCPUs, numberJobs, i);

    if (results == nilResult) {
        results = newResult;
    } else {
        results = new TestResult(results, newResult);
    }

    // I copied over the code from runTest because I can't figure out what's going on...
}

writeln(results);



proc runTest(numCPUs : int, numberJobs : int, modeIndex : int) : TestResult {
    var rng = new NPBRandomStream(real);

    var mode = modes[modeIndex];

    var goals : [scoresDomain] real = maxGoals;
    if (mode == "average") {
        goals = avgGoals;
    } else if (mode == "hybrid") {
        goals = hybridGoals;
    }

    var efficiencyGoals = goals[modeIndex];

    var jobs = new JobGroup();
    var scheduler = new Scheduler(mode);

    //ask the scheduler how big of a queue it wants.
    var queueCapacity = scheduler.getOutputQueueCapacity(numCPUs);

    //create the queue between scheduler and CPUs
    var schedulerToCPUs = new BlockingQueue(Job, queueCapacity);
    scheduler.setOutputQueue(schedulerToCPUs);

    //create the cpus
    var cpusDomain = {0..numCPUs-1};
    var cpus : [cpusDomain] CPU;
    forall i in cpus.domain {
        cpus[i] = new CPU(schedulerToCPUs, "" + i);
        begin{
            cpus[i].start();
        }
    }


    //Throw a first round of jobs at the Scheduler!
    var firstRoundSize = max(10, 3 * numCPUs);
    forall i in 1..(firstRoundSize) {
        var nextFactor = rng.getNext();
        //writeln("nextFactor: ", nextFactor);
        //writeln("maxTime: ", maxTime);
        var jobLength = nextFactor * maxTime;
        //writeln("jobLength: ", jobLength);
        var job = new Job(jobLength);
        jobs.add(job); //add it to the group
        scheduler.addJob(job);
    }

    var numRemainingJobs = numberJobs - firstRoundSize;

    //Throw the rest of the jobs at the Scheduler
    //for each cpu, create a separate thread to add jobs
    coforall i in cpusDomain {
        for j in 1..(numRemainingJobs / numCPUs) {
            var job = new Job(rng.getNext() * maxTime);
            jobs.add(job);
            begin { scheduler.addJob(job); } //don't wait on this
            sleep(.96 * (rng.getNext() * maxTime));
        }
    }

    //get the appropriate score
    var efficiencyMeasure = jobs.reportStats(modeIndex);
    var score = 0;
    var maxScore = scores[0];
    var goalMade = "none";

    for i in scores.domain {
        var nextScore = scores[i];
        var goal = goals[i];
        if (efficiencyMeasure < goal) {
            score = nextScore;
            goalMade = goal + "s";
            break;
        }
    }
    var description = "Results of " + mode + " test:\nRecorded time: " + efficiencyMeasure + "s.\nBest goal passed: " + goalMade + "\nPoints earned: " + score + "/" + maxScore + "\n\n";

    writeln(description);

    forall i in cpus.domain {
        cpus[i].stop();
    }
    scheduler.stop();

    return new TestResult(score, maxScore, description);

    /* Old version

    writeln(mode + " test results:\nGoal: " + efficiencyGoal + "\nActual: " + efficiencyMeasure);
    if (efficiencyMeasure <= efficiencyGoal) {
        writeln("Passed the " + mode + " test!  Great Job!");
    } else {
        writeln("Failed the " + mode + " test!  Hmmmmm...");
    }
    */

}


//This represents the result of a test.
class TestResult {
    var score : int;
    var maxScore : int;
    var description : string;

    proc TestResult(score: int, maxScore : int, description : string) {
        this.score = score;
        this.maxScore = maxScore;
        this.description = description;
    }

    proc TestResult(resultA : TestResult, resultB : TestResult) {
        this.score = resultA.getScore() + resultB.getScore();
        this.maxScore = resultA.getMaxScore() + resultB.getMaxScore();
        this.description = resultA.getDescription() + "\n\n" + resultB.getDescription();
    }

    proc getScore() : int {
        return this.score;
    }

    proc getMaxScore() : int {
        return this.maxScore;
    }

    proc getDescription() : string {
        return this.description;
    }

    proc writeThis(writer) {
        writer.writeln("Total tests score: " + this.getScore() + "/" + this.maxScore);
        writer.write(this.getDescription());
    }

}



//This represents a set of Jobs.  It is used to report stats about those jobs.
class JobGroup {

    var jobsDomain = {0..1};

    var jobs : [jobsDomain] Job;

    var numJobs : int;

    var synchronizer : Semaphore;

    proc JobGroup() {
        this.numJobs = 0;
        this.synchronizer = new Semaphore(1);
    }

    proc add(job : Job) {
        this.synchronizer.p();
        if (this.numJobs == this.jobsDomain.numIndices) {
            this.jobsDomain = {0..(this.jobsDomain.high * 2)};
        }
        this.jobs[this.numJobs] = job;
        this.numJobs += 1;
        this.synchronizer.v();
    }

    proc allCompleted() : bool {
        for jobIndex in 0..(this.numJobs-1) {
            if (!this.jobs[jobIndex].isDone()) {
                return false;
            }
        }
        return true;
    }

    proc reportStats(statIndex : int) : real {
        //wait for the jobs to complete
        while (!this.allCompleted()) {
            writeln("Jobs are still running.");
            sleep(1);
        }

        var totalWaitTime = 0.0;
        var maxWaitTime = 0.0;

        for jobIndex in 0..(this.numJobs-1) {
            var job = this.jobs[jobIndex];
            totalWaitTime += job.getWaitTime();
            maxWaitTime = max(maxWaitTime, job.getWaitTime());
        }

        var avgWaitTime = totalWaitTime / this.numJobs;
        var hybridWaitTime = 2 * avgWaitTime + maxWaitTime;

        writeln("~~~~~~~~~~~~~~~~~~~~~~");
        writeln("Job stats calculated!");
        writeln(this.numJobs, " jobs completed!");
        writeln("Maximum wait time: ", maxWaitTime);
        writeln("Average wait time: ", avgWaitTime);
        writeln("Hybrid wait time (max + 2 x avg): ", hybridWaitTime);
        writeln("~~~~~~~~~~~~~~~~~~~~~~~");

        var stats : [0..2] real;
        stats = (maxWaitTime, avgWaitTime, hybridWaitTime);

        return stats[statIndex];
    }

} //end of JobGroup class
