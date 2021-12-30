variable "lambda11_bucket" {
    type = string
    default = "a"
}

variable "lambda_role"{
    type = string
}

variable "sqs_err_queue"{
    type = string
}

variable "data_dyna_table"{
    type = string
    default="a"
}

variable "tracking_dyna_table"{
    type = string
    default=""
}