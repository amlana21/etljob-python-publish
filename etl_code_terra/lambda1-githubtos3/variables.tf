variable "lambda_role"{
    type = string
}

variable "lambda1_buckets" {
    type = list
    default = ["a","b"]
}

variable "src_file_bucket"{
    default = "a"
}

variable "git_file_src"{
    default = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us.csv"
}

variable "git_file_src_2"{
    default = "https://raw.githubusercontent.com/datasets/covid-19/master/data/time-series-19-covid-combined.csv"
}

variable "etl_load_table"{
    default = ""
}


variable "output_file_name"{
    default = ""
}