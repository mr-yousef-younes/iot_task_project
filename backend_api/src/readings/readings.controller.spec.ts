import { Test, TestingModule } from '@nestjs/testing';
import { ReadingsController } from './readings.controller';

describe('ReadingsController', () => {
  let controller: ReadingsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ReadingsController],
    }).compile();

    controller = module.get<ReadingsController>(ReadingsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
