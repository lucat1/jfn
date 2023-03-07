type SchedulerCallBackRequest {
    jobName: string
    groupName: string
}

interface SchedulerCallBackInterface {
  OneWay:
    schedulerCallback( SchedulerCallBackRequest )
}
