NAME = inception
CXX = c++

DIR_OBJ = obj/
SRC_DIR = src/
INC_DIR = inc/

CXXFLAGS = -Wall -Wextra -Werror -std=c++98
INCLUDES = -I $(INC_DIR)

SRCS =
SRCS_BONUS =
include srcs.mk

OBJS = ${patsubst %.cpp,$(DIR_OBJ)%.o, $(shell echo $(SRCS) | sed "s|$(SRC_DIR)||g")}
DEPS = ${patsubst %.o,%.d, $(OBJS)}

-include $(DEPS)

MAKEFLAGS += -j $(shell nproc)

MODE ?= debug

ifeq ($(filter $(MODE),debug release),)
$(error MODE must be 'debug' or 'release')
endif

ifeq ($(MODE),debug)
	CXXFLAGS += -O0 -g3 -D DEBUG=1
	DEBUG = 1
	TARGET = debug
endif

ifeq ($(MODE),release)
	CXXFLAGS += -O3 -flto -D DEBUG=0
	DEBUG = 0
	TARGET = release
endif

.SILENT:

.PHONY: all
all: gen_srcs
all: $(NAME)

test: export CFLAGS += -DUNITTEST=1
test: all

test_bonus: export CFLAGS += -DUNITTEST=1
test_bonus: bonus

.PHONY: bonus
bonus: export CFLAGS += -DBONUS=1
bonus: all

###########################################################
######################### TOOLS ###########################
###########################################################

define gen_srcs_file
	$(shell echo "# Auto-generated file, do not edit!" > srcs.mk)
	$(shell echo -n "SRCS += " >> srcs.mk)
	$(shell find src -type f -name "*.cpp" | sed "s/.*_bonus.cpp//" | sed '$$ ! s/$$/ \\/' >> srcs.mk)
endef

.PHONY: gen_srcs
gen_srcs:
	$(call gen_srcs_file)

.PHONY: cachegrind
cachegrind:
	valgrind --tool=cachegrind ./$(NAME) $(ARGS)

.PHONY: callgrind
callgrind:
	valgrind --tool=callgrind --dump-instr=yes --collect-jumps=yes ./$(NAME) $(ARGS)

########################## RULES ###########################

%/:
	mkdir -p $@

$(DIR_OBJ)%.o: $(SRC_DIR)%.cpp
	echo "Compiling $*.cpp"
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(NAME): $(DIR_OBJ) $(OBJS) Makefile
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $(NAME) $(OBJS)


.PHONY: clean
clean:
	rm -Rf $(DIR_OBJ)

.PHONY: fclean
fclean: clean
	rm -f $(NAME)
	printf '# Auto-generated file, do not edit!\nSRCS +=\n' > srcs.mk

.PHONY: re
re: fclean
re: all

.DEFAULT_GOAL = all
