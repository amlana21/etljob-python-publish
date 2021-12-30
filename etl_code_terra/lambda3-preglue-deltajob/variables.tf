variable "lambda3_bucket" {
    type = string
    default = "a"
}

variable "lambda_role"{
    type = string
}

variable "sqs_err_queue"{
    type = string
}

variable "dyna_table"{
    type = string
    default=""
}