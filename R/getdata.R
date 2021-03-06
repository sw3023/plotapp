#' Get data 
#' 
#' Wrapper for calling survey_response/read
#' 
#' @param campaign_urn Campaign_urn
#' @param severurl Http(s) address of Ohmage server (including /app)
#' @param token authentication token
#' @param ... passed on to oh.survey_response.read
#' @importFrom Ohmage oh.survey_response.read
#' @export
getdata <- function(campaign_urn, serverurl, token, ...){
  if(grepl("^urn:public:", campaign_urn)){
    demoname <- paste0(sub("urn:public:", "", campaign_urn))
    demoname <- match.arg(demoname, c("snack", "nutrition", "media", "trash"))
    href <- paste0(serverurl, "/../navbar/demo/data/", demoname, "/", demoname, "demo.csv")
    mydata <- demodata(href, ...)
  } else {
    mydata <- oh.survey_response.read(campaign_urn, serverurl = serverurl, token = token, 
      column_list = "urn:ohmage:user:id,urn:ohmage:prompt:response,urn:ohmage:context:timestamp,urn:ohmage:survey:privacy_state", ...);
    if(nrow(mydata) == 0){
      stop("No survey responses found for this campaign/range.")
    }
    names(mydata) <- sub("^prompt\\.id\\.", "", names(mydata));
  }

  # Make sure to pass timezone = "" otherwise date has different date than timestamp
  mydata$datetime <- as.POSIXct(mydata$context.timestamp, "");
  mydata$date <- as.Date(mydata$datetime, "")
  mydata$day <- ordered(format(mydata$datetime, "%A"), levels = c("Monday", 
    "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",  "Sunday"))
  
  # ggplot2 requires an explicit timezone here
  local_tz <- format(Sys.time(), "%Z")
  mydata$time <- as.POSIXct(strptime(substring(mydata$context.timestamp, 12), format = "%H:%M:%S"), local_tz);
  
  # these variables are not available for demo data 
  mydata$user <- if(length(mydata$user.id)) as.factor(mydata$user.id) else factor("demo");
  mydata$privacy <-if(length(mydata$survey.privacy_state)) as.factor(mydata$survey.privacy_state) else factor("shared")
  
  #remove redundant columns
  mydata$survey.privacy_state <- NULL;
  mydata$context.timestamp <- NULL;
  
  #hack for later
  class(mydata$time) <- c("time_of_day", class(mydata$time))
  
  #return ze data
  invisible(mydata);
}

#' @importFrom curl curl
demodata <- function(href, start_date = "2000-01-01", end_date = "2050-01-01", ...){
  mydata <- read.csv(curl(href), stringsAsFactors = FALSE)
  dates <- as.Date(mydata$context.timestamp)
  subset(mydata, dates > start_date & dates < end_date)
  choicevars <- grep("\\.label$", names(mydata))
  if(length(choicevars)){
    mydata[choicevars] <- lapply(mydata[choicevars], as.factor)
  }
  names(mydata) <- sub("\\.label$", "", names(mydata));
  return(mydata)
}
